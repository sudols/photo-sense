import uuid
import os
import json
from django.utils import timezone
from django.http import JsonResponse
from django.views import View
from django.views.decorators.csrf import csrf_exempt
from django.utils.decorators import method_decorator
from rest_framework_simplejwt.authentication import JWTAuthentication
from rest_framework.exceptions import AuthenticationFailed

from .models import Photo, Person, PhotoPerson
from .ml import index_faces, detect_text, search_faces
from .storage import upload_to_s3, delete_from_s3, get_presigned_url


# Helper functions to replace serializers
def photo_to_dict(photo):
    """Convert Photo model instance to dictionary."""
    return {
        "id": str(photo.id),
        "s3_key": photo.s3_key,
        "url": get_presigned_url(photo.s3_key),
        "face_ids": photo.face_ids,
        "detected_text": photo.detected_text,
        "detected_faces": photo.detected_faces,
        "faces_count": photo.faces_count,
        "analyzed_at": photo.analyzed_at.isoformat() if photo.analyzed_at else None,
        "created_at": photo.created_at.isoformat(),
        "updated_at": photo.updated_at.isoformat(),
    }


def person_to_dict(person, include_photos=False):
    """Convert Person model instance to dictionary."""
    data = {
        "id": str(person.id),
        "name": person.name,
        "face_id": person.face_id,
        "face_ids": person.face_ids,
        "bounding_box": person.bounding_box,
        "thumbnail_s3_key": person.thumbnail_s3_key,
        "thumbnail_url": get_presigned_url(person.thumbnail_s3_key)
        if person.thumbnail_s3_key
        else None,
        "is_unnamed": person.is_unnamed,
        "created_at": person.created_at.isoformat(),
        "updated_at": person.updated_at.isoformat(),
    }

    if include_photos:
        photos = Photo.objects.filter(photo_persons__person=person)
        data["photos"] = [photo_to_dict(p) for p in photos]
    else:
        data["photos"] = None

    return data


# Base class for authenticated views
@method_decorator(csrf_exempt, name="dispatch")
class AuthenticatedView(View):
    """Base view that handles JWT authentication."""

    def dispatch(self, request, *args, **kwargs):
        # Authenticate using JWT
        jwt_auth = JWTAuthentication()
        try:
            auth_result = jwt_auth.authenticate(request)
            if auth_result is not None:
                request.user, _ = auth_result
            else:
                return JsonResponse({"error": "Authentication required"}, status=401)
        except AuthenticationFailed:
            return JsonResponse({"error": "Invalid or expired token"}, status=401)

        return super().dispatch(request, *args, **kwargs)

    def json_response(self, data, status=200):
        """Helper to return JSON response."""
        return JsonResponse(data, status=status, safe=False)

    def get_json_data(self):
        """Helper to parse JSON from request body."""
        try:
            return json.loads(self.request.body) if self.request.body else {}
        except json.JSONDecodeError:
            return {}


class PhotoUploadView(AuthenticatedView):
    """Handle photo upload with face detection and clustering."""

    def post(self, request):
        file = request.FILES.get("file")
        if not file:
            return self.json_response({"error": "no file provided"}, status=400)

        # Enforce maximum 3MB file size limit to prevent AWS bandwidth/S3/Rekognition abuse
        MAX_SIZE_BYTES = 5 * 1024 * 1024  # 5MB
        if file.size > MAX_SIZE_BYTES:
            return self.json_response(
                {"error": "File size exceeds 5MB limit. Please upload a smaller compressed image."},
                status=400,
            )

        # Enforce maximum 30 photos total per portfolio user account to protect S3 storage and Rekognition budget
        existing_count = Photo.objects.filter(owner=request.user).count()
        if existing_count >= 30:
            return self.json_response(
                {"error": "Portfolio upload quota exceeded: Limit of 30 photos per account reached."},
                status=403,
            )

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

        return self.json_response(photo_to_dict(photo), status=201)


def _cluster_face(face, photo, user):
    """Find or create a Person for this face, then link to the photo."""
    face_id = face["face_id"]
    matched_id = search_faces(face_id)
    person = None

    if matched_id:
        # Find person who owns the matched face
        # Use Python-side filtering — face_ids__contains on JSONField
        # is not reliable across all database backends.
        person = next(
            (p for p in Person.objects.filter(owner=user) if matched_id in p.face_ids),
            None,
        )
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


class PhotoListView(AuthenticatedView):
    """List all photos for the authenticated user."""

    def get(self, request):
        photos = Photo.objects.filter(owner=request.user)
        return self.json_response([photo_to_dict(p) for p in photos])


class PhotoDetailView(AuthenticatedView):
    """Get, update, or delete a single photo."""

    def get(self, request, pk):
        try:
            photo = Photo.objects.get(id=pk, owner=request.user)
            return self.json_response(photo_to_dict(photo))
        except Photo.DoesNotExist:
            return self.json_response({"error": "Photo not found"}, status=404)

    def delete(self, request, pk):
        try:
            photo = Photo.objects.get(id=pk, owner=request.user)
            delete_from_s3(photo.s3_key)
            photo.delete()
            return self.json_response({"message": "Photo deleted"}, status=204)
        except Photo.DoesNotExist:
            return self.json_response({"error": "Photo not found"}, status=404)


class PhotoSearchView(AuthenticatedView):
    """Search photos by detected text."""

    def get(self, request):
        query = request.GET.get("q", "").strip()
        if not query:
            return self.json_response([])

        # Server-side search — fixes the current client-side full-scan bug
        photos = Photo.objects.filter(
            owner=request.user, detected_text__icontains=query
        )
        return self.json_response([photo_to_dict(p) for p in photos])


class PersonListView(AuthenticatedView):
    """List all persons for the authenticated user."""

    def get(self, request):
        persons = Person.objects.filter(owner=request.user)
        return self.json_response([person_to_dict(p) for p in persons])


class PersonDetailView(AuthenticatedView):
    """Get, update, or delete a single person."""

    def get(self, request, pk):
        try:
            person = Person.objects.get(id=pk, owner=request.user)
            # Include photos on detail view
            return self.json_response(person_to_dict(person, include_photos=True))
        except Person.DoesNotExist:
            return self.json_response({"error": "Person not found"}, status=404)

    def patch(self, request, pk):
        try:
            person = Person.objects.get(id=pk, owner=request.user)
            data = self.get_json_data()

            # Update allowed fields
            if "name" in data:
                person.name = data["name"]
                person.is_unnamed = False
            if "is_unnamed" in data:
                person.is_unnamed = data["is_unnamed"]

            person.save()
            return self.json_response(person_to_dict(person, include_photos=True))
        except Person.DoesNotExist:
            return self.json_response({"error": "Person not found"}, status=404)

    def delete(self, request, pk):
        try:
            person = Person.objects.get(id=pk, owner=request.user)
            person.delete()
            return self.json_response({"message": "Person deleted"}, status=204)
        except Person.DoesNotExist:
            return self.json_response({"error": "Person not found"}, status=404)


class PersonMergeView(AuthenticatedView):
    """Merge two persons together."""

    def post(self, request, pk):
        try:
            from_person = Person.objects.get(id=pk, owner=request.user)
        except Person.DoesNotExist:
            return self.json_response({"error": "Person not found"}, status=404)

        data = self.get_json_data()
        merge_into_id = data.get("merge_into_id")

        try:
            to_person = Person.objects.get(id=merge_into_id, owner=request.user)
        except Person.DoesNotExist:
            return self.json_response({"error": "target person not found"}, status=404)

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
        return self.json_response(person_to_dict(to_person))
