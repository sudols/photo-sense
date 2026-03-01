import uuid
import os
from django.utils import timezone
from rest_framework import viewsets
from rest_framework.views import APIView
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.parsers import MultiPartParser

from .models import Photo, Person, PhotoPerson
from .serializers import PhotoSerializer, PersonSerializer
from .ml import index_faces, detect_text, search_faces
from .storage import upload_to_s3, delete_from_s3, get_presigned_url


class PhotoUploadView(APIView):
    parser_classes = [MultiPartParser]

    def post(self, request):
        file = request.FILES.get("file")
        if not file:
            return Response({"error": "no file provided"}, status=400)

        image_bytes = file.read()
        ext = os.path.splitext(file.name)[1].lower() or ".jpg"
        s3_key = f"photos/{request.user.id}/{uuid.uuid4()}{ext}"
        content_type = file.content_type or "image/jpeg"

        # 1. Upload to S3
        upload_to_s3(image_bytes, s3_key, content_type)

        # 2. Run Rekognition (synchronous — takes ~3-7s, fine for this scale)
        detected_faces = index_faces(image_bytes)
        detected_text = detect_text(image_bytes)

        # 3. Save Photo record
        photo = Photo.objects.create(
            owner=request.user,
            s3_key=s3_key,
            face_ids=[f["face_id"] for f in detected_faces],
            detected_text=detected_text,
            detected_faces=detected_faces,
            faces_count=len(detected_faces),
            analyzed_at=timezone.now(),
        )

        # 4. Face clustering — create/update Person + PhotoPerson records
        for face in detected_faces:
            _cluster_face(face, photo, request.user)

        return Response(
            PhotoSerializer(photo, context={"request": request}).data, status=201
        )


def _cluster_face(face, photo, user):
    """Find or create a Person for this face, then link to the photo."""
    face_id = face["face_id"]
    matched_id = search_faces(face_id)
    person = None

    if matched_id:
        # Find person who owns the matched face
        person = Person.objects.filter(
            owner=user,
            face_ids__contains=matched_id,
        ).first()
        if person and face_id not in person.face_ids:
            person.face_ids.append(face_id)
            person.save(update_fields=["face_ids", "updated_at"])

    if not person:
        person = Person.objects.create(
            owner=user,
            name="Unknown Person",
            face_id=face_id,
            face_ids=[face_id],
            bounding_box=face["bounding_box"],
            thumbnail_s3_key=photo.s3_key,
            is_unnamed=True,
        )

    PhotoPerson.objects.get_or_create(
        photo=photo, person=person, defaults={"owner": user}
    )


class PhotoViewSet(viewsets.ModelViewSet):
    serializer_class = PhotoSerializer

    def get_queryset(self):
        return Photo.objects.filter(owner=self.request.user)

    def perform_destroy(self, instance):
        delete_from_s3(instance.s3_key)
        instance.delete()

    @action(detail=False, methods=["get"])
    def search(self, request):
        query = request.query_params.get("q", "").strip()
        if not query:
            return Response([])
        # Server-side search — fixes the current client-side full-scan bug
        photos = self.get_queryset().filter(detected_text__icontains=query)
        return Response(
            PhotoSerializer(photos, many=True, context={"request": request}).data
        )


class PersonViewSet(viewsets.ModelViewSet):
    serializer_class = PersonSerializer

    def get_queryset(self):
        return Person.objects.filter(owner=self.request.user)

    def retrieve(self, request, *args, **kwargs):
        # Include photos only on detail view
        instance = self.get_object()
        serializer = self.get_serializer(
            instance,
            context={**self.get_serializer_context(), "include_photos": True},
        )
        return Response(serializer.data)

    @action(detail=True, methods=["post"])
    def merge(self, request, pk=None):
        from_person = self.get_object()
        merge_into_id = request.data.get("merge_into_id")
        try:
            to_person = Person.objects.get(id=merge_into_id, owner=request.user)
        except Person.DoesNotExist:
            return Response({"error": "target person not found"}, status=404)

        # Merge face_ids
        combined = list(set(to_person.face_ids + from_person.face_ids))
        to_person.face_ids = combined
        if not to_person.face_id and from_person.face_id:
            to_person.face_id = from_person.face_id
        to_person.save()

        # Re-link PhotoPerson records
        PhotoPerson.objects.filter(person=from_person, owner=request.user).update(
            person=to_person
        )

        from_person.delete()
        return Response(PersonSerializer(to_person).data)
