# Django Backend — Build Plan

## Context

- **Driver:** Course requirement — professor recommends Django
- **Purpose:** Fresh rebuild of the Amplify backend. No data migration needed.
- **Scale:** Educational / showcase project, 2-3 users max
- **Goal:** Simple stack, single process, free hosting

---

## Stack

| Layer           | Choice                           | Reason                                               |
| --------------- | -------------------------------- | ---------------------------------------------------- |
| API             | Django REST Framework            | Standard, well-documented                            |
| Database        | SQLite (dev) / PostgreSQL (prod) | Zero config locally; same ORM code either way        |
| Background jobs | None — synchronous               | No Celery, no Redis; Rekognition runs inline (~3-7s) |
| Storage         | S3 (existing bucket)             | Rekognition-proven; persistent across deploys        |
| ML              | Rekognition via boto3            | Same API calls, just Python                          |
| Auth            | djangorestframework-simplejwt    | Standard JWT; no Cognito dependency                  |
| Deployment      | Render (free tier)               | Auto-detects Django; free Postgres included          |

### Architecture

```
Flutter App
    |
    | REST (JWT)
    v
Django REST Framework
    |           \
PostgreSQL    Celery — NO. Rekognition is called synchronously in the view.
              boto3 → S3 (file storage)
              boto3 → Rekognition (face index, OCR)
```

### What Was Dropped vs the Old Plan

| Old Plan                        | New Plan                  | Reason                          |
| ------------------------------- | ------------------------- | ------------------------------- |
| Celery                          | Removed                   | Overkill for 3-4 users          |
| Redis                           | Removed                   | No broker needed                |
| PostgreSQL (required)           | Optional — SQLite for dev | Zero config; same code          |
| Pre-signed URL upload (3 steps) | Single upload endpoint    | Simpler Flutter side            |
| ArrayField (Postgres-only)      | JSONField                 | Works on both SQLite + Postgres |
| DynamoDB migration script       | Removed                   | Fresh rebuild, no existing data |

---

## Repository Location

```
flutter-photos/
├── photo_sense/          ← Flutter app (unchanged for now)
└── photosense_backend/   ← new Django project (this plan)
```

---

## Project Structure

```
photosense_backend/
├── manage.py
├── requirements.txt
├── .env.example
├── render.yaml               ← Render deploy config
├── photosense/
│   ├── __init__.py
│   ├── settings.py           ← SQLite dev / Postgres prod via DATABASE_URL
│   ├── urls.py
│   └── wsgi.py
└── photos/
    ├── __init__.py
    ├── models.py             ← Photo, Person, PhotoPerson
    ├── serializers.py        ← DRF serializers (Photo URL injected here)
    ├── views.py              ← ViewSets + upload (sync Rekognition)
    ├── urls.py               ← DRF router
    ├── ml.py                 ← boto3 Rekognition wrapper
    ├── storage.py            ← boto3 S3 upload / delete / presigned URL
    └── admin.py              ← all models registered
```

---

## Requirements

```
# requirements.txt
django>=4.2
djangorestframework
djangorestframework-simplejwt
django-cors-headers
dj-database-url
boto3
python-dotenv
Pillow
gunicorn
```

8 packages total. No Celery, no Redis, no psycopg2 for local dev.

---

## Environment Variables

```bash
# .env  (copy from .env.example)
SECRET_KEY=your-django-secret-key
DEBUG=True

# Omit DATABASE_URL locally → SQLite is used automatically
# DATABASE_URL=postgres://user:pass@host:5432/photosense  ← set this on Render

# AWS
AWS_ACCESS_KEY_ID=your-access-key
AWS_SECRET_ACCESS_KEY=your-secret-key
AWS_REGION=ap-south-1
S3_BUCKET_NAME=your-s3-bucket-name
REKOGNITION_COLLECTION_ID=photosense-faces
```

---

## Data Models

```python
# photos/models.py

import uuid
from django.db import models
from django.contrib.auth.models import User


class Photo(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    owner = models.ForeignKey(User, on_delete=models.CASCADE, related_name='photos')
    s3_key = models.CharField(max_length=500)
    face_ids = models.JSONField(default=list, blank=True)        # list of Rekognition FaceIds
    detected_text = models.JSONField(default=list, blank=True)   # list of OCR line strings
    detected_faces = models.JSONField(default=list, blank=True)  # list of {faceId, boundingBox, confidence}
    faces_count = models.IntegerField(default=0)
    analyzed_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"Photo({self.id})"


class Person(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    owner = models.ForeignKey(User, on_delete=models.CASCADE, related_name='persons')
    name = models.CharField(max_length=255, default='Unknown Person')
    face_id = models.CharField(max_length=100, blank=True)           # primary/first face
    face_ids = models.JSONField(default=list, blank=True)            # all face IDs for this person
    bounding_box = models.JSONField(null=True, blank=True)           # {Left, Top, Width, Height}
    thumbnail_s3_key = models.CharField(max_length=500, blank=True)
    is_unnamed = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return self.name


class PhotoPerson(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    photo = models.ForeignKey(Photo, on_delete=models.CASCADE, related_name='photo_persons')
    person = models.ForeignKey(Person, on_delete=models.CASCADE, related_name='photo_persons')
    owner = models.ForeignKey(User, on_delete=models.CASCADE)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('photo', 'person')

    def __str__(self):
        return f"{self.person.name} in {self.photo.id}"
```

Key differences from the Amplify schema:

- Proper FK constraints — no manual ID tracking
- `JSONField` instead of `ArrayField` — works on both SQLite and PostgreSQL
- `unique_together` on PhotoPerson — replaces manual dedup in the old Lambda

---

## Settings

```python
# photosense/settings.py (relevant parts)

import dj_database_url
from pathlib import Path
from dotenv import load_dotenv
import os

load_dotenv()

SECRET_KEY = os.environ['SECRET_KEY']
DEBUG = os.getenv('DEBUG', 'False') == 'True'

ALLOWED_HOSTS = ['*']   # tighten for production

INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'rest_framework',
    'rest_framework_simplejwt',
    'corsheaders',
    'photos',
]

MIDDLEWARE = [
    'corsheaders.middleware.CorsMiddleware',   # must be first
    'django.middleware.security.SecurityMiddleware',
    # ... rest of defaults
]

# Database: SQLite locally, Postgres on Render
DATABASES = {
    'default': dj_database_url.config(default='sqlite:///db.sqlite3')
}

# CORS: allow Flutter app (any origin in dev)
# Android does not enforce CORS (browser-only mechanism) — this only matters if
# the DRF Browsable API is used from a browser during development.
CORS_ALLOW_ALL_ORIGINS = DEBUG

REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': [
        'rest_framework_simplejwt.authentication.JWTAuthentication',
    ],
    'DEFAULT_PERMISSION_CLASSES': [
        'rest_framework.permissions.IsAuthenticated',
    ],
}

from datetime import timedelta
SIMPLE_JWT = {
    'ACCESS_TOKEN_LIFETIME': timedelta(days=1),
    'REFRESH_TOKEN_LIFETIME': timedelta(days=30),
}

STATIC_ROOT = Path(BASE_DIR) / 'staticfiles'
```

---

## Auth Endpoints

```python
# photosense/urls.py

from django.urls import path, include
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView
from photos.auth_views import RegisterView

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/auth/register/', RegisterView.as_view()),
    path('api/auth/login/',    TokenObtainPairView.as_view()),
    path('api/auth/refresh/',  TokenRefreshView.as_view()),
    path('api/', include('photos.urls')),
]
```

```python
# photos/auth_views.py

from django.contrib.auth.models import User
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.permissions import AllowAny


class RegisterView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        email = request.data.get('email', '').lower().strip()
        password = request.data.get('password', '')

        if not email or not password:
            return Response({'error': 'email and password required'}, status=400)

        if User.objects.filter(username=email).exists():
            return Response({'error': 'email already registered'}, status=400)

        User.objects.create_user(username=email, email=email, password=password)
        return Response({'message': 'account created'}, status=status.HTTP_201_CREATED)
```

Email is stored as `username` so simplejwt's `TokenObtainPairView` works without a custom serializer.
Login body: `{"username": "<email>", "password": "<password>"}`.

---

## ML Layer

```python
# photos/ml.py

import boto3
import os

rekognition = boto3.client('rekognition', region_name=os.getenv('AWS_REGION', 'ap-south-1'))
COLLECTION_ID = os.getenv('REKOGNITION_COLLECTION_ID', 'photosense-faces')


def ensure_collection():
    existing = rekognition.list_collections().get('CollectionIds', [])
    if COLLECTION_ID not in existing:
        rekognition.create_collection(CollectionId=COLLECTION_ID)


def index_faces(image_bytes):
    """Index faces in image, return list of {face_id, bounding_box, confidence}."""
    response = rekognition.index_faces(
        CollectionId=COLLECTION_ID,
        Image={'Bytes': image_bytes},
        DetectionAttributes=['DEFAULT'],
    )
    faces = []
    for record in response.get('FaceRecords', []):
        face = record['Face']
        faces.append({
            'face_id': face['FaceId'],
            'bounding_box': face['BoundingBox'],
            'confidence': face['Confidence'],
        })
    return faces


def detect_text(image_bytes):
    """Return list of detected text lines with confidence > 80%."""
    response = rekognition.detect_text(Image={'Bytes': image_bytes})
    return [
        d['DetectedText']
        for d in response.get('TextDetections', [])
        if d['Type'] == 'LINE' and d['Confidence'] > 80
    ]


def search_faces(face_id):
    """Return the best-matching face_id from the collection, or None."""
    response = rekognition.search_faces(
        CollectionId=COLLECTION_ID,
        FaceId=face_id,
        FaceMatchThreshold=90,
        MaxFaces=1,
    )
    matches = response.get('FaceMatches', [])
    if matches:
        return matches[0]['Face']['FaceId']
    return None
```

Rekognition receives image bytes directly — it never needs to access S3 itself.
This removes the IAM requirement for Rekognition to have S3 read access.

---

## Storage Layer

```python
# photos/storage.py

import boto3
import os

s3 = boto3.client('s3', region_name=os.getenv('AWS_REGION', 'ap-south-1'))
BUCKET = os.getenv('S3_BUCKET_NAME')


def upload_to_s3(file_bytes, s3_key, content_type='image/jpeg'):
    s3.put_object(Bucket=BUCKET, Key=s3_key, Body=file_bytes, ContentType=content_type)


def delete_from_s3(s3_key):
    s3.delete_object(Bucket=BUCKET, Key=s3_key)


def get_presigned_url(s3_key, expiry_seconds=604800):  # 7 days
    return s3.generate_presigned_url(
        'get_object',
        Params={'Bucket': BUCKET, 'Key': s3_key},
        ExpiresIn=expiry_seconds,
    )
```

S3 key structure: `photos/{user_id}/{uuid}.{ext}`
No Cognito identity IDs in the path.

---

## Upload Flow (Core Feature)

```python
# photos/views.py (upload endpoint)

import uuid
import os
from django.utils import timezone
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.parsers import MultiPartParser

from .models import Photo, Person, PhotoPerson
from .serializers import PhotoSerializer
from .ml import index_faces, detect_text, search_faces
from .storage import upload_to_s3, get_presigned_url


class PhotoUploadView(APIView):
    parser_classes = [MultiPartParser]

    def post(self, request):
        file = request.FILES.get('file')
        if not file:
            return Response({'error': 'no file provided'}, status=400)

        image_bytes = file.read()
        ext = os.path.splitext(file.name)[1].lower() or '.jpg'
        s3_key = f"photos/{request.user.id}/{uuid.uuid4()}{ext}"
        content_type = file.content_type or 'image/jpeg'

        # 1. Upload to S3
        upload_to_s3(image_bytes, s3_key, content_type)

        # 2. Run Rekognition (synchronous — takes ~3-7s, fine for this scale)
        detected_faces = index_faces(image_bytes)
        detected_text = detect_text(image_bytes)

        # 3. Save Photo record
        photo = Photo.objects.create(
            owner=request.user,
            s3_key=s3_key,
            face_ids=[f['face_id'] for f in detected_faces],
            detected_text=detected_text,
            detected_faces=detected_faces,
            faces_count=len(detected_faces),
            analyzed_at=timezone.now(),
        )

        # 4. Face clustering — create/update Person + PhotoPerson records
        for face in detected_faces:
            _cluster_face(face, photo, request.user)

        return Response(PhotoSerializer(photo, context={'request': request}).data, status=201)


def _cluster_face(face, photo, user):
    """Find or create a Person for this face, then link to the photo."""
    face_id = face['face_id']
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
            person.save(update_fields=['face_ids', 'updated_at'])

    if not person:
        person = Person.objects.create(
            owner=user,
            name='Unknown Person',
            face_id=face_id,
            face_ids=[face_id],
            bounding_box=face['bounding_box'],
            thumbnail_s3_key=photo.s3_key,
            is_unnamed=True,
        )

    PhotoPerson.objects.get_or_create(photo=photo, person=person, defaults={'owner': user})
```

The `face_ids__contains=matched_id` query:

- PostgreSQL: would use GIN-indexed JSONB containment if a `GinIndex` migration is added — not automatic, and unnecessary at this scale
- SQLite: uses JSON1 extension — works correctly, slower but fine for this scale

---

## Full API Endpoints

```python
# photos/urls.py

from django.urls import path
from rest_framework.routers import DefaultRouter
from .views import PhotoViewSet, PersonViewSet, PhotoUploadView

router = DefaultRouter()
router.register('photos', PhotoViewSet, basename='photo')
router.register('persons', PersonViewSet, basename='person')

urlpatterns = [
    path('photos/upload/', PhotoUploadView.as_view()),  # must be before router
] + router.urls
```

```
Auth
  POST  /api/auth/register/              body: {email, password}
  POST  /api/auth/login/                 body: {username: email, password} → {access, refresh}
  POST  /api/auth/refresh/               body: {refresh} → {access}

Photos
  GET   /api/photos/                     list (owner-scoped, newest first)
  POST  /api/photos/upload/              multipart: file → uploads + analyzes → returns Photo
  GET   /api/photos/{id}/                single photo
  DELETE /api/photos/{id}/               deletes DB record + S3 file
  GET   /api/photos/search/?q=text       server-side text search

Persons
  GET   /api/persons/                    list all persons (named + unnamed)
  GET   /api/persons/{id}/               person detail + their photos
  PATCH /api/persons/{id}/               rename: body: {name, is_unnamed: false}
  DELETE /api/persons/{id}/
  POST  /api/persons/{id}/merge/         body: {merge_into_id} → merges face_ids + PhotoPersons
```

---

## Serializers

```python
# photos/serializers.py

from rest_framework import serializers
from .models import Photo, Person, PhotoPerson
from .storage import get_presigned_url


class PhotoSerializer(serializers.ModelSerializer):
    url = serializers.SerializerMethodField()

    class Meta:
        model = Photo
        fields = [
            'id', 's3_key', 'url', 'face_ids', 'detected_text',
            'detected_faces', 'faces_count', 'analyzed_at', 'created_at',
        ]

    def get_url(self, obj):
        return get_presigned_url(obj.s3_key)


class PersonSerializer(serializers.ModelSerializer):
    thumbnail_url = serializers.SerializerMethodField()
    photos = serializers.SerializerMethodField()

    class Meta:
        model = Person
        fields = [
            'id', 'name', 'face_id', 'face_ids', 'bounding_box',
            'thumbnail_s3_key', 'thumbnail_url', 'is_unnamed',
            'created_at', 'photos',
        ]

    def get_thumbnail_url(self, obj):
        if obj.thumbnail_s3_key:
            return get_presigned_url(obj.thumbnail_s3_key)
        return None

    def get_photos(self, obj):
        # Only included on detail view to avoid N+1 on list
        if self.context.get('include_photos'):
            photos = Photo.objects.filter(photo_persons__person=obj)
            return PhotoSerializer(photos, many=True, context=self.context).data
        return None
```

---

## ViewSets

```python
# photos/views.py (ViewSets, in addition to PhotoUploadView above)

from rest_framework import viewsets, filters
from rest_framework.decorators import action
from rest_framework.response import Response
from .storage import delete_from_s3


class PhotoViewSet(viewsets.ModelViewSet):
    serializer_class = PhotoSerializer

    def get_queryset(self):
        return Photo.objects.filter(owner=self.request.user)

    def perform_destroy(self, instance):
        delete_from_s3(instance.s3_key)
        instance.delete()

    @action(detail=False, methods=['get'])
    def search(self, request):
        query = request.query_params.get('q', '').strip()
        if not query:
            return Response([])
        # Server-side search — fixes the current client-side full-scan bug
        photos = self.get_queryset().filter(detected_text__icontains=query)
        return Response(PhotoSerializer(photos, many=True, context={'request': request}).data)


class PersonViewSet(viewsets.ModelViewSet):
    serializer_class = PersonSerializer

    def get_queryset(self):
        return Person.objects.filter(owner=self.request.user)

    def retrieve(self, request, *args, **kwargs):
        # Include photos only on detail view
        instance = self.get_object()
        serializer = self.get_serializer(instance, context={**self.get_serializer_context(), 'include_photos': True})
        return Response(serializer.data)

    @action(detail=True, methods=['post'])
    def merge(self, request, pk=None):
        from_person = self.get_object()
        merge_into_id = request.data.get('merge_into_id')
        try:
            to_person = Person.objects.get(id=merge_into_id, owner=request.user)
        except Person.DoesNotExist:
            return Response({'error': 'target person not found'}, status=404)

        # Merge face_ids
        combined = list(set(to_person.face_ids + from_person.face_ids))
        to_person.face_ids = combined
        if not to_person.face_id and from_person.face_id:
            to_person.face_id = from_person.face_id
        to_person.save()

        # Re-link PhotoPerson records
        PhotoPerson.objects.filter(person=from_person, owner=request.user).update(person=to_person)

        from_person.delete()
        return Response(PersonSerializer(to_person).data)
```

---

## Deployment (Render)

```yaml
# render.yaml

services:
  - type: web
    name: photosense-backend
    runtime: python
    buildCommand: 'pip install -r requirements.txt && python manage.py migrate && python manage.py collectstatic --noinput'
    startCommand: 'gunicorn photosense.wsgi'
    envVars:
      - key: SECRET_KEY
        generateValue: true
      - key: DEBUG
        value: 'False'
      - key: DATABASE_URL
        fromDatabase:
          name: photosense-db
          property: connectionString
      - key: AWS_ACCESS_KEY_ID
        sync: false
      - key: AWS_SECRET_ACCESS_KEY
        sync: false
      - key: AWS_REGION
        value: ap-south-1
      - key: S3_BUCKET_NAME
        sync: false
      - key: REKOGNITION_COLLECTION_ID
        value: photosense-faces

databases:
  - name: photosense-db
    plan: free
```

Connect your GitHub repo on Render → it reads `render.yaml` → deploys automatically on push.

Free tier note: web service sleeps after 15 min of inactivity. One warm-up request before a demo is all that's needed.

---

## Running Locally

```bash
# One-time setup
cd photosense_backend
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env        # fill in AWS credentials
python manage.py migrate
python manage.py createsuperuser

# Run
python manage.py runserver  # that's it — one command, one process
```

Django Admin available at `http://localhost:8000/admin` — full UI to inspect all data.
DRF Browsable API at `http://localhost:8000/api/photos/` — test endpoints without Postman.

---

## Build Phases

### Phase 1 — Project Setup

- [ ] `django-admin startproject photosense_backend`
- [ ] Create `photos` app
- [ ] Configure `settings.py` (SQLite, JWT, CORS, REST_FRAMEWORK)
- [ ] Write `requirements.txt`
- [ ] Write `.env.example`

### Phase 2 — Models + Admin

- [ ] Write `photos/models.py` (Photo, Person, PhotoPerson)
- [ ] Run `python manage.py makemigrations && migrate`
- [ ] Register all models in `photos/admin.py`
- [ ] Verify via Django Admin at `/admin`

### Phase 3 — Auth

- [ ] Write `photos/auth_views.py` (RegisterView)
- [ ] Wire auth URLs in `photosense/urls.py`
- [ ] Test: register → login → get access token

### Phase 4 — Storage + ML

- [ ] Write `photos/storage.py` (S3 upload, delete, presigned URL)
- [ ] Write `photos/ml.py` (Rekognition index, detect, search)
- [ ] Create the Rekognition collection once: `python manage.py shell -c "from photos.ml import ensure_collection; ensure_collection()"`
- [ ] Test both independently in Django shell

### Phase 5 — Upload Endpoint

- [ ] Write `PhotoUploadView` with `_cluster_face` logic
- [ ] Wire to `photos/urls.py`
- [ ] Test: upload a photo → verify S3 file + DB record + Person created

### Phase 6 — Remaining CRUD + Search

- [ ] Write `PhotoViewSet`, `PersonViewSet` with merge action
- [ ] Write serializers with presigned URL injection
- [ ] Test all endpoints via DRF Browsable API

### Phase 7 — Deploy to Render

- [ ] Write `render.yaml`
- [ ] Push to GitHub
- [ ] Connect repo on Render → set AWS env vars
- [ ] Verify live URL works end-to-end

---

## Improvements Over the Old Amplify Backend

| Issue (Amplify)                                            | Fix (Django)                                       |
| ---------------------------------------------------------- | -------------------------------------------------- |
| Search fetches all data to device, filters in Flutter      | Server-side `detected_text__icontains` query       |
| Lambda scans entire Person table per face (ScanCommand)    | Indexed ORM query (`face_ids__contains`)           |
| 3-step upload: presigned URL → S3 PUT → AppSync create     | Single `POST /api/photos/upload/`                  |
| `detectedFaces` type mismatch (JSON string double-encoded) | Clean `JSONField`, no double-decode                |
| Rekognition required S3 IAM access                         | Rekognition gets image bytes — no S3 access needed |
| No admin UI for debugging                                  | Django Admin at `/admin` for free                  |
| Auth tied to AWS Cognito (can't run without AWS)           | Self-contained Django JWT                          |
