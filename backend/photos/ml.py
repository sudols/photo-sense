import boto3
import os
from functools import lru_cache

COLLECTION_ID = os.getenv("REKOGNITION_COLLECTION_ID", "photosense-faces")


@lru_cache(maxsize=1)
def _get_rekognition_client():
    return boto3.client(
        "rekognition", region_name=os.getenv("AWS_REGION", "ap-south-1")
    )


def ensure_collection():
    """Create the Rekognition collection if it doesn't exist."""
    client = _get_rekognition_client()
    existing = client.list_collections().get("CollectionIds", [])
    if COLLECTION_ID not in existing:
        client.create_collection(CollectionId=COLLECTION_ID)


def index_faces(image_bytes):
    """Index faces in image, return list of {face_id, bounding_box, confidence}."""
    client = _get_rekognition_client()
    response = client.index_faces(
        CollectionId=COLLECTION_ID,
        Image={"Bytes": image_bytes},
        DetectionAttributes=["DEFAULT"],
    )
    faces = []
    for record in response.get("FaceRecords", []):
        face = record["Face"]
        faces.append(
            {
                "face_id": face["FaceId"],
                "bounding_box": face["BoundingBox"],
                "confidence": face["Confidence"],
            }
        )
    return faces


def detect_text(image_bytes):
    """Return list of detected text lines with confidence > 80%."""
    client = _get_rekognition_client()
    response = client.detect_text(Image={"Bytes": image_bytes})
    return [
        d["DetectedText"]
        for d in response.get("TextDetections", [])
        if d["Type"] == "LINE" and d["Confidence"] > 80
    ]


def search_faces(face_id):
    """Return the best-matching face_id from the collection, or None."""
    try:
        client = _get_rekognition_client()
        response = client.search_faces(
            CollectionId=COLLECTION_ID,
            FaceId=face_id,
            FaceMatchThreshold=40,
            MaxFaces=1,
        )
        matches = response.get("FaceMatches", [])
        if matches:
            return matches[0]["Face"]["FaceId"]
    except Exception:
        pass
    return None
