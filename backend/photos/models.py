import uuid
from django.db import models
from django.contrib.auth.models import User


class Photo(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    owner = models.ForeignKey(User, on_delete=models.CASCADE, related_name="photos")
    s3_key = models.CharField(max_length=500)
    face_ids = models.JSONField(default=list, blank=True)  # list of Rekognition FaceIds
    detected_text = models.JSONField(
        default=list, blank=True
    )  # list of OCR line strings
    detected_faces = models.JSONField(
        default=list, blank=True
    )  # list of {faceId, boundingBox, confidence}
    faces_count = models.IntegerField(default=0)
    analyzed_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return f"Photo({self.id})"


class Person(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    owner = models.ForeignKey(User, on_delete=models.CASCADE, related_name="persons")
    name = models.CharField(max_length=255, default="Unknown Person")
    face_id = models.CharField(max_length=100, blank=True)  # primary/first face
    face_ids = models.JSONField(
        default=list, blank=True
    )  # all face IDs for this person
    bounding_box = models.JSONField(null=True, blank=True)  # {Left, Top, Width, Height}
    thumbnail_s3_key = models.CharField(max_length=500, blank=True)
    is_unnamed = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return self.name


class PhotoPerson(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    photo = models.ForeignKey(
        Photo, on_delete=models.CASCADE, related_name="photo_persons"
    )
    person = models.ForeignKey(
        Person, on_delete=models.CASCADE, related_name="photo_persons"
    )
    owner = models.ForeignKey(User, on_delete=models.CASCADE)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ("photo", "person")

    def __str__(self):
        return f"{self.person.name} in {self.photo.id}"
