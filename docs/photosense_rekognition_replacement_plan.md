# PhotoSense — AWS Rekognition Replacement Plan
### From-Scratch ML Implementation | `photos/ml.py` Migration

---

## Overview

This document outlines a phased plan to fully replace the three AWS Rekognition boto3 calls in `photos/ml.py` with a self-contained, from-scratch implementation using pure Python, numpy, and OpenCV image decoding. No AWS credentials, no boto3 Rekognition dependency, and no external ML library abstractions.

**Scope:** `backend/photos/ml.py` only. `views.py`, `_cluster_face()`, all models, serializers, URLs, and S3 storage are **untouched**. The three public function signatures remain identical:

```python
index_faces(image_bytes) -> list[dict]
detect_text(image_bytes) -> list[str]
search_faces(face_id)    -> str | None
```

**New dependencies (minimal):**
- `numpy` — already in requirements
- `opencv-python-headless` — image decode/encode only (no detection calls)
- `tesseract` — OS-level binary, installed via apt, not a Python library

**Removed dependencies:**
- `boto3` Rekognition client and all three Rekognition API calls
- `REKOGNITION_COLLECTION_ID` environment variable
- `ensure_collection()` management command

---

## Phase 0 — Preparation

**Goal:** Set up the new file structure, install dependencies, and establish the replacement skeleton before touching any logic.

### 0.1 — Install System Dependencies

Add `tesseract-ocr` to your Render build environment. On Render, this is done via a `render.yaml` build command or a `packages.txt` file:

```
# packages.txt (create in repo root if it doesn't exist)
tesseract-ocr
```

For local development on Ubuntu/Debian:

```bash
sudo apt install tesseract-ocr
```

On macOS:

```bash
brew install tesseract
```

### 0.2 — Update `requirements.txt`

Remove the Rekognition-specific boto3 usage note and ensure these are present:

```
numpy
opencv-python-headless
```

> boto3 can stay in requirements if S3 storage still uses it — only the Rekognition client import is removed from `ml.py`.

### 0.3 — Download the Haar Cascade Data File

The Viola-Jones face detector requires a pre-trained cascade XML file as its data source. This is not a library — it is a structured data file of threshold values that your code parses manually.

```bash
# From repo root
cd backend/photos/
curl -L -o haarcascade_frontalface_default.xml \
  https://raw.githubusercontent.com/opencv/opencv/master/data/haarcascades/haarcascade_frontalface_default.xml
```

Commit this file to the repository. It is 930KB and is static — it never needs updating.

### 0.4 — Create the New `ml.py` Skeleton

Rename the existing file as a backup, then create a fresh `ml.py` with the three empty function stubs and a module-level embedding store:

```python
# photos/ml.py  — new from-scratch implementation
import numpy as np
import cv2
import uuid
import subprocess
import tempfile
import os
import xml.etree.ElementTree as ET
from pathlib import Path

# In-memory face embedding store: { face_id (str): embedding (list[float]) }
# Populated by index_faces(), queried by search_faces()
_embedding_store: dict = {}

CASCADE_PATH = Path(__file__).parent / "haarcascade_frontalface_default.xml"


def index_faces(image_bytes: bytes) -> list:
    raise NotImplementedError

def detect_text(image_bytes: bytes) -> list:
    raise NotImplementedError

def search_faces(face_id: str) -> str | None:
    raise NotImplementedError
```

Verify the Django server still starts and the `/api/photos/upload/` endpoint returns a 500 with `NotImplementedError` — this confirms the wiring is intact before any logic is written.

---

## Phase 1 — Implement `detect_text()`

**Goal:** Replace `rekognition.detect_text()` with a self-written Otsu binarization pipeline feeding into the `tesseract` OS binary.

**Why this phase first:** It has zero dependency on the face detection or clustering logic, can be tested independently with any image, and validates the tesseract system install before the more complex phases.

### 1.1 — Implement Otsu's Thresholding (Pure Numpy)

Otsu's method finds the optimal binary threshold by maximizing inter-class variance between foreground and background pixel intensities. The implementation iterates over all 256 possible thresholds and picks the one that maximizes:

\[ \sigma_B^2(t) = \omega_0(t)\,\omega_1(t)\,[\mu_0(t) - \mu_1(t)]^2 \]

where \(\omega_0, \omega_1\) are the class weights (pixel proportions) and \(\mu_0, \mu_1\) are the class means at threshold \(t\).

```python
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
```

### 1.2 — Implement `detect_text()`

```python
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
```

### 1.3 — Test Phase 1

```bash
# From Django shell
python manage.py shell
>>> from photos.ml import detect_text
>>> with open("test_image.jpg", "rb") as f: data = f.read()
>>> detect_text(data)
['Exit Sign', 'Floor 3']  # expected: list of strings
```

The `detect_text()` call in `PhotoUploadView.post()` passes `image_bytes` directly — no changes needed in `views.py`.

---

## Phase 2 — Implement `index_faces()`

**Goal:** Replace `rekognition.index_faces()` with a from-scratch Viola-Jones sliding window detector using an integral image, manual Haar cascade evaluation, and numpy NMS.

### 2.1 — Parse the Cascade XML

The `haarcascade_frontalface_default.xml` file contains cascade stages, each with weak classifiers defined by rectangular Haar features and their thresholds. Parse this into a Python data structure:

```python
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

    stages = []
    for stage in cascade.findall(".//stage"):
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
            rects = []
            for r in tree_elem.findall(".//rects/_"):
                parts = r.text.split()
                rects.append((int(parts[1]), int(parts[0]),
                               int(parts[3]), int(parts[2]),
                               float(parts[4])))
            weak_classifiers.append((rects, thresh, left_val, right_val))
        stages.append((stage_thresh, weak_classifiers))

    return win_size, stages
```

### 2.2 — Integral Image and Rectangle Sum (Pure Numpy)

```python
def _integral_image(img: np.ndarray) -> np.ndarray:
    """
    Compute the summed area table (integral image).
    ii[r, c] = sum of all pixels in the rectangle (0,0) to (r-1, c-1).
    Pure numpy cumulative sum — O(n) time, O(n) space.
    """
    padded = np.zeros((img.shape[0] + 1, img.shape[1] + 1), dtype=np.float64)
    padded[1:, 1:] = img
    return padded.cumsum(axis=0).cumsum(axis=1)


def _rect_sum(ii: np.ndarray, r: int, c: int, h: int, w: int) -> float:
    """O(1) rectangle sum using pre-computed integral image."""
    return (ii[r + h, c + w]
            - ii[r, c + w]
            - ii[r + h, c]
            + ii[r, c])
```

### 2.3 — Cascade Evaluator and Sliding Window

```python
def _passes_cascade(ii: np.ndarray, stages: list, scale: float,
                    row: int, col: int) -> bool:
    """
    Evaluate all cascade stages at the given window position and scale.
    Returns True only if every stage threshold is passed.
    """
    for stage_thresh, weak_classifiers in stages:
        stage_sum = 0.0
        for (rects, thresh, left_val, right_val) in weak_classifiers:
            feat_sum = sum(
                wt * _rect_sum(ii,
                               row + int(r * scale),
                               col + int(c * scale),
                               max(1, int(h * scale)),
                               max(1, int(w * scale)))
                for (r, c, h, w, wt) in rects
            )
            stage_sum += left_val if feat_sum < thresh else right_val
        if stage_sum < stage_thresh:
            return False
    return True
```

### 2.4 — Non-Maximum Suppression (Pure Numpy)

Overlapping detection windows at the same face are collapsed to a single bounding box using IoU (Intersection over Union):

\[ \text{IoU}(A, B) = \frac{|A \cap B|}{|A \cup B|} \]

```python
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
```

### 2.5 — Implement `index_faces()`

```python
_cascade_cache = None  # load once per process

def _get_cascade():
    global _cascade_cache
    if _cascade_cache is None:
        _cascade_cache = _load_cascade(CASCADE_PATH)
    return _cascade_cache


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
    win_size, stages = _get_cascade()

    raw_boxes = []
    scale = 1.0
    while True:
        win = int(win_size * scale)
        if win > img_h or win > img_w:
            break
        step = max(1, win // 8)
        for r in range(0, img_h - win, step):
            for c in range(0, img_w - win, step):
                if _passes_cascade(ii, stages, scale, r, c):
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
```

### 2.6 — Test Phase 2

```bash
python manage.py shell
>>> from photos.ml import index_faces
>>> with open("group_photo.jpg", "rb") as f: data = f.read()
>>> index_faces(data)
[{'face_id': 'uuid...', 'bounding_box': {...}, 'confidence': 95.0}, ...]
```

Expected: one dict per detected face with a UUID `face_id` and normalized bounding box.

---

## Phase 3 — Implement `search_faces()`

**Goal:** Replace `rekognition.search_faces()` — which queries an AWS-managed vector collection — with an in-process cosine similarity search over color histogram embeddings stored in `_embedding_store`.

### 3.1 — Face Histogram Embedding (Pure Numpy)

Each detected face crop is represented as a 192-dimensional L1-normalized color histogram (64 bins × 3 BGR channels). This is the "embedding" that substitutes for Rekognition's deep face vector:

```python
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
```

### 3.2 — Cosine Similarity (Pure Numpy)

\[ \text{sim}(a, b) = \frac{a \cdot b}{\|a\| \cdot \|b\|} \]

```python
def _cosine_similarity(a: list, b: list) -> float:
    """Cosine similarity between two embedding vectors. Pure numpy."""
    va, vb = np.array(a), np.array(b)
    denom = np.linalg.norm(va) * np.linalg.norm(vb)
    return float(np.dot(va, vb) / denom) if denom > 1e-8 else 0.0
```

### 3.3 — Implement `search_faces()`

```python
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

    for fid, vec in _embedding_store.items():
        if fid == face_id:
            continue
        score = _cosine_similarity(query_vec, vec)
        if score > best_score:
            best_score, best_id = score, fid

    return best_id if best_score >= threshold else None
```

### 3.4 — Test Phase 3

```bash
python manage.py shell
>>> from photos.ml import index_faces, search_faces
>>> with open("photo_a.jpg", "rb") as f: a = f.read()
>>> with open("photo_b_same_person.jpg", "rb") as f: b = f.read()
>>> faces_a = index_faces(a)
>>> faces_b = index_faces(b)
>>> search_faces(faces_b[0]["face_id"])
# Should return face_id from faces_a if the same person appears in both photos
```

At this point all three functions are implemented. The full upload flow through `PhotoUploadView` → `_cluster_face()` should work end-to-end.

---

## Phase 4 — Remove AWS Rekognition

**Goal:** Clean up all Rekognition references from the codebase now that the replacement is confirmed working.

### 4.1 — Remove from `ml.py`

Delete:
- `import boto3`
- `_get_rekognition_client()`
- `ensure_collection()`
- `COLLECTION_ID` constant

None of these are called by `views.py` or any other module.

### 4.2 — Remove Environment Variables

From `.env.example` and `render.yaml`, remove:

```bash
# DELETE these — no longer used
REKOGNITION_COLLECTION_ID=photosense-faces
```

Keep all `AWS_*` variables — they are still needed for S3 storage.

### 4.3 — Remove Management Command Reference

The `ensure_collection()` call documented in the project README (Appendix D) is no longer needed. Remove from setup instructions:

```bash
# DELETE from onboarding docs:
python manage.py shell -c "from photos.ml import ensure_collection; ensure_collection()"
```

### 4.4 — Update `requirements.txt`

```
# Verify these are present
numpy
opencv-python-headless

# boto3 stays — still used by storage.py for S3
boto3
```

---

## Phase 5 — End-to-End Validation

**Goal:** Confirm the full upload pipeline, clustering, and search work correctly with the new implementation.

### 5.1 — Full Upload Flow Test

```bash
# Register and login
curl -X POST http://localhost:8000/api/auth/register/ \
  -H "Content-Type: application/json" \
  -d '{"email": "test@test.com", "password": "pass123"}'

TOKEN=$(curl -s -X POST http://localhost:8000/api/auth/login/ \
  -H "Content-Type: application/json" \
  -d '{"username": "test@test.com", "password": "pass123"}' | python3 -c "import sys,json; print(json.load(sys.stdin)['access'])")

# Upload a photo with a face
curl -X POST http://localhost:8000/api/photos/upload/ \
  -H "Authorization: Bearer $TOKEN" \
  -F "file=@face_photo.jpg"

# Upload the same person again — should cluster to existing Person
curl -X POST http://localhost:8000/api/photos/upload/ \
  -H "Authorization: Bearer $TOKEN" \
  -F "file=@same_person_2.jpg"

# Check persons — should be 1 person with 2 face_ids
curl http://localhost:8000/api/persons/ \
  -H "Authorization: Bearer $TOKEN"
```

### 5.2 — OCR Search Test

```bash
# Upload an image with visible text
curl -X POST http://localhost:8000/api/photos/upload/ \
  -H "Authorization: Bearer $TOKEN" \
  -F "file=@text_image.jpg"

# Search for the detected text
curl "http://localhost:8000/api/photos/search/?q=exit" \
  -H "Authorization: Bearer $TOKEN"
```

### 5.3 — Validation Checklist

| Check | Expected Result |
|---|---|
| Upload returns 201 | `detected_faces` list populated, `face_ids` non-empty |
| Second upload of same person | `GET /api/persons/` shows 1 person, 2 face_ids |
| Upload of different person | `GET /api/persons/` shows 2 distinct persons |
| OCR text visible in response | `detected_text` list contains the visible words |
| Text search returns correct photo | `GET /api/photos/search/?q=word` returns matching photo |
| No boto3 Rekognition errors | Server logs show zero `rekognition` references |
| `ensure_collection()` not required | Server starts cleanly without Rekognition collection setup |

---

## Summary

| Phase | What Changes | Files Modified |
|---|---|---|
| **0 — Prep** | Install tesseract, download cascade XML, create skeleton | `packages.txt`, `requirements.txt`, `ml.py`, `haarcascade_frontalface_default.xml` |
| **1 — OCR** | Otsu binarization + tesseract subprocess | `ml.py` |
| **2 — Face Detection** | Integral image + Haar cascade + NMS | `ml.py` |
| **3 — Face Similarity** | Histogram embedding + cosine search | `ml.py` |
| **4 — Cleanup** | Remove Rekognition client, env vars, setup command | `ml.py`, `.env.example`, `render.yaml`, `README` |
| **5 — Validation** | End-to-end curl tests | None |

`views.py`, `models.py`, `storage.py`, `serializers.py`, `urls.py`, and all migrations are **not modified at any phase.**

