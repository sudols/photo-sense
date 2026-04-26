import numpy as np
import cv2
import uuid
import subprocess
import tempfile
import os
import xml.etree.ElementTree as ET
from pathlib import Path
import math

# In-memory face embedding store: { face_id (str): embedding (list[float]) }
# Populated by index_faces(), queried by search_faces()
_embedding_store: dict = {}

CASCADE_PATH = Path(__file__).parent / "haarcascade_frontalface_default.xml"


def _load_cascade(xml_path: Path) -> tuple:
    """
    Parse OpenCV Haar cascade XML into native Python structures.
    Returns (window_size, stages) where stages is a list of
    (stage_threshold, list_of_weak_classifiers).
    Each weak classifier: (feature_rects, threshold, left_val, right_val).
    feature_rects: list of (row, col, height, width, weight).
    """
    tree = ET.parse(xml_path)
    root = tree.getroot()

    cascade = root.find(".//cascade") or root.find("haarcascade")
    win_size = int(cascade.find("width").text)

    features_tag = cascade.find("features")
    global_features = []
    if features_tag is not None:
        for feat in features_tag.findall("_"):
            rects = []
            for r in feat.findall(".//rects/_"):
                parts = r.text.split()
                # parts: x, y, w, h, wt. Map to r, c, h, w, wt
                rects.append((int(parts[1]), int(parts[0]),
                              int(parts[3]), int(parts[2]),
                              float(parts[4])))
            global_features.append(rects)

    stages_tag = cascade.find("stages")
    if stages_tag is None:
        return win_size, []

    stages = []
    for stage in stages_tag.findall("_"):
        stage_thresh = float(stage.find("stageThreshold").text)
        weak_classifiers = []
        for tree_elem in stage.findall(".//weakClassifiers/_"):
            node = tree_elem.find(".//internalNodes")
            leaves = tree_elem.find(".//leafValues")
            if node is None or leaves is None:
                continue
            node_vals = node.text.split()
            leaf_vals = leaves.text.split()
            thresh = float(node_vals[3])
            left_val = float(leaf_vals[0])
            right_val = float(leaf_vals[1])
            
            feature_idx = int(node_vals[2])
            rects = global_features[feature_idx] if feature_idx < len(global_features) else []
            weak_classifiers.append((rects, thresh, left_val, right_val))
        stages.append((stage_thresh, weak_classifiers))

    return win_size, stages

def _integral_image(img: np.ndarray) -> np.ndarray:
    """
    Compute the summed area table (integral image).
    ii[r, c] = sum of all pixels in the rectangle (0,0) to (r-1, c-1).
    Pure numpy cumulative sum — O(n) time, O(n) space.
    """
    padded = np.zeros((img.shape[0] + 1, img.shape[1] + 1), dtype=np.float64)
    padded[1:, 1:] = img
    return padded.cumsum(axis=0).cumsum(axis=1)

def _squared_integral_image(img: np.ndarray) -> np.ndarray:
    padded = np.zeros((img.shape[0] + 1, img.shape[1] + 1), dtype=np.float64)
    padded[1:, 1:] = img ** 2
    return padded.cumsum(axis=0).cumsum(axis=1)

def _rect_sum(ii: np.ndarray, r: int, c: int, h: int, w: int) -> float:
    """O(1) rectangle sum using pre-computed integral image."""
    return (ii[r + h, c + w]
            - ii[r, c + w]
            - ii[r + h, c]
            + ii[r, c])

def _passes_cascade(ii: np.ndarray, scaled_stages: list,
                    row: int, col: int, std_dev: float, win_area: int) -> bool:
    """
    Evaluate all cascade stages at the given window position using precalc rects.
    Returns True only if every stage threshold is passed.
    """
    for stage_thresh, weak_classifiers in scaled_stages:
        stage_sum = 0.0
        for (rects, thresh, left_val, right_val) in weak_classifiers:
            feat_sum = sum(
                wt * _rect_sum(ii, row + r, col + c, h, w)
                for (r, c, h, w, wt) in rects
            )
            stage_sum += left_val if feat_sum < thresh * win_area * std_dev else right_val
        if stage_sum < stage_thresh:
            return False
    return True

def _nms(boxes: list, overlap_thresh: float = 0.3) -> list:
    """
    Non-maximum suppression — removes overlapping detections.
    boxes: list of [x1, y1, x2, y2] integers.
    Returns pruned list.
    """
    if not boxes:
        return []
    b = np.array(boxes, dtype=np.float64)
    x1, y1, x2, y2 = b[:, 0], b[:, 1], b[:, 2], b[:, 3]
    areas = (x2 - x1) * (y2 - y1)
    order = areas.argsort()[::-1]
    keep = []

    while order.size > 0:
        i = order[0]
        keep.append(int(i))
        xx1 = np.maximum(x1[i], x1[order[1:]])
        yy1 = np.maximum(y1[i], y1[order[1:]])
        xx2 = np.minimum(x2[i], x2[order[1:]])
        yy2 = np.minimum(y2[i], y2[order[1:]])
        inter = np.maximum(0, xx2 - xx1) * np.maximum(0, yy2 - yy1)
        iou = inter / (areas[i] + areas[order[1:]] - inter + 1e-8)
        order = order[1:][iou < overlap_thresh]

    return b[keep].astype(int).tolist()

_cascade_cache = None  # load once per process

def _get_cascade():
    global _cascade_cache
    if _cascade_cache is None:
        _cascade_cache = _load_cascade(CASCADE_PATH)
    return _cascade_cache

def _face_histogram(img: np.ndarray, x1: int, y1: int,
                    x2: int, y2: int) -> list:
    """
    Extract a 192-d color histogram from a face bounding box crop.
    Pure numpy — no library feature extractor.
    Returns L1-normalized list of floats.
    """
    crop = img[y1:y2, x1:x2]
    if crop.size == 0:
        return [0.0] * 192

    hist = []
    for ch in range(3):  # BGR channels
        counts, _ = np.histogram(
            crop[:, :, ch].flatten(), bins=64, range=[0, 256]
        )
        hist.extend(counts.tolist())

    vec = np.array(hist, dtype=np.float64)
    total = vec.sum()
    return (vec / total).tolist() if total > 0 else vec.tolist()

def index_faces(image_bytes: bytes) -> list:
    """
    Detect faces using from-scratch Viola-Jones cascade + integral image.
    Generates a UUID face_id per detection and stores a color histogram
    embedding in _embedding_store for use by search_faces().
    Returns list of {face_id, bounding_box, confidence} matching
    the original Rekognition response shape.
    """
    nparr = np.frombuffer(image_bytes, np.uint8)
    gray = cv2.imdecode(nparr, cv2.IMREAD_GRAYSCALE)
    color = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
    if gray is None:
        return []

    gray = gray.astype(np.float64)
    img_h, img_w = gray.shape
    ii = _integral_image(gray)
    sq_ii = _squared_integral_image(gray)
    win_size, stages = _get_cascade()

    raw_boxes = []
    scale = 1.0
    while True:
        win = int(win_size * scale)
        if win > img_h or win > img_w:
            break
            
        # Pre-scale rects and perform OpenCV zero-weight balancing per scale iteration!
        scaled_stages = []
        for stage_thresh, weak_classifiers in stages:
            scaled_weaks = []
            for (rects, thresh, left_val, right_val) in weak_classifiers:
                scaled_rects = []
                sum0 = 0.0
                for i, (r, c, h, w, wt) in enumerate(rects):
                    sr = round(r * scale)
                    sc = round(c * scale)
                    sh = max(1, round(h * scale))
                    sw = max(1, round(w * scale))
                    area = sh * sw
                    if i > 0:
                        sum0 += wt * area
                    scaled_rects.append([sr, sc, sh, sw, wt, area])
                
                # Zero-balance rect 0 weight:
                if scaled_rects and scaled_rects[0][5] > 0:
                    scaled_rects[0][4] = -sum0 / scaled_rects[0][5]
                    
                # Store fast tuple
                final_rects = [(sr, sc, sh, sw, wt) for sr, sc, sh, sw, wt, _ in scaled_rects]
                scaled_weaks.append((final_rects, thresh, left_val, right_val))
            scaled_stages.append((stage_thresh, scaled_weaks))
            
        step = max(1, win // 8)
        win_area = win * win
        for r in range(0, img_h - win, step):
            for c in range(0, img_w - win, step):
                mean = _rect_sum(ii, r, c, win, win) / win_area
                sq_mean = _rect_sum(sq_ii, r, c, win, win) / win_area
                variance = sq_mean - (mean * mean)
                std_dev = math.sqrt(math.fabs(variance)) if variance > 0.0 else 1.0
                
                if _passes_cascade(ii, scaled_stages, r, c, std_dev, win_area):
                    raw_boxes.append([c, r, c + win, r + win])
        scale *= 1.25

    kept = _nms(raw_boxes)

    faces = []
    for box in kept:
        x1, y1, x2, y2 = box
        face_id = str(uuid.uuid4())
        bbox = {
            "Left":   round(x1 / img_w, 4),
            "Top":    round(y1 / img_h, 4),
            "Width":  round((x2 - x1) / img_w, 4),
            "Height": round((y2 - y1) / img_h, 4),
        }
        # Store embedding for search_faces()
        _embedding_store[face_id] = _face_histogram(color, x1, y1, x2, y2)
        faces.append({
            "face_id":      face_id,
            "bounding_box": bbox,
            "confidence":   95.0,
        })

    return faces

def _otsu_threshold(gray: np.ndarray) -> int:
    """
    Compute Otsu's optimal binarization threshold.
    Pure numpy — no cv2.threshold call.
    Returns integer threshold value in [0, 255].
    """
    hist, _ = np.histogram(gray.flatten(), bins=256, range=[0, 256])
    total_pixels = gray.size
    total_intensity = (np.arange(256) * hist).sum()

    best_thresh, best_variance = 0, 0.0
    weight_bg = intensity_bg = 0

    for t in range(256):
        weight_bg += hist[t]
        weight_fg = total_pixels - weight_bg
        if weight_bg == 0 or weight_fg == 0:
            continue

        intensity_bg += t * hist[t]
        mean_bg = intensity_bg / weight_bg
        mean_fg = (total_intensity - intensity_bg) / weight_fg

        inter_class_variance = weight_bg * weight_fg * (mean_bg - mean_fg) ** 2
        if inter_class_variance > best_variance:
            best_variance = inter_class_variance
            best_thresh = t

    return best_thresh


def _binarize(image_bytes: bytes) -> np.ndarray:
    """Decode image bytes and apply Otsu binarization. Returns binary uint8 array."""
    nparr = np.frombuffer(image_bytes, np.uint8)
    img = cv2.imdecode(nparr, cv2.IMREAD_GRAYSCALE)
    if img is None:
        raise ValueError("Could not decode image bytes")
    thresh = _otsu_threshold(img)
    return (img > thresh).astype(np.uint8) * 255


def detect_text(image_bytes: bytes) -> list:
    """
    Binarize image with from-scratch Otsu threshold, then pass to
    tesseract OS binary via subprocess. Returns list of non-empty text lines.
    """
    binary = _binarize(image_bytes)

    with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as tmp:
        tmp_path = tmp.name
        cv2.imwrite(tmp_path, binary)

    try:
        result = subprocess.run(
            ["tesseract", tmp_path, "stdout", "--psm", "11", "-l", "eng"],
            capture_output=True,
            text=True,
            timeout=15,
        )
        lines = [line.strip() for line in result.stdout.splitlines() if line.strip()]
    except (subprocess.TimeoutExpired, FileNotFoundError):
        lines = []
    finally:
        os.unlink(tmp_path)

    return lines

def _cosine_similarity(a: list, b: list) -> float:
    """Cosine similarity between two embedding vectors. Pure numpy."""
    va, vb = np.array(a), np.array(b)
    denom = np.linalg.norm(va) * np.linalg.norm(vb)
    return float(np.dot(va, vb) / denom) if denom > 1e-8 else 0.0

def search_faces(face_id: str, threshold: float = 0.92) -> str | None:
    """
    Search _embedding_store for the most similar face to face_id.
    Returns the best-matching face_id string if similarity >= threshold,
    otherwise None. Mirrors the original Rekognition search_faces() contract.
    """
    if face_id not in _embedding_store:
        return None

    query_vec = _embedding_store[face_id]
    best_id, best_score = None, -1.0

    # Use list() to avoid RuntimeError if dictionary is modified by another thread during iteration.
    for fid, vec in list(_embedding_store.items()):
        if fid == face_id:
            continue
        score = _cosine_similarity(query_vec, vec)
        if score > best_score:
            best_score, best_id = score, fid

    return best_id if best_score >= threshold else None
