# PhotoSense — AI-Powered Photo Management System
### Project Report | BCA Programme

---

## Acknowledgement

So first of all, I want to sincerely thank our project guide and the faculty of our department for giving us the opportunity to work on this project. Without their constant support and the feedback they gave us during the development phases, completing this would have been much harder. And also thanks to the institution for providing the resources and the lab environment that made testing and building this project possible. This project was a great learning experience overall, and we are really grateful for the guidance we received throughout.

---

## Abstract

PhotoSense is a backend-focused web application built using Django REST Framework that allows users to upload, organize, and intelligently search through their photo library. The system integrates with AWS Rekognition for automatic face detection and OCR (optical character recognition), and uses AWS S3 for cloud-based photo storage. When a user uploads a photo, the system runs face detection and text recognition synchronously, clusters detected faces into person profiles, and stores all results in a relational database. Authentication is handled through JWT tokens using the djangorestframework-simplejwt library. The backend exposes 13 REST API endpoints that cover photo upload, search, person management, and user auth. A Flutter mobile frontend is currently in development and is not part of the current implementation scope. All current testing and demonstration is done directly through the Django API using CLI tools and the DRF browsable interface.

---

## Table of Contents

| Section | Page |
|---|---|
| Acknowledgement | 2 |
| Abstract | 3 |
| Table of Contents | 4 |
| Introduction | 5 |
| Literature / Existing System | 6 |
| Proposed System | 7 |
| System Design | 8 |
| Methodology | 9 |
| Implementation | 10 |
| Results & Output | 12 |
| Conclusion | 13 |
| Future Scope | 13 |
| References | 14 |
| Appendix | 15 |

---

## Introduction

### Background

So, the problem of organizing a personal photo library is something most people deal with but don't really have a clean solution for. Traditional photo apps just sort by date and that's about it. The idea behind PhotoSense is to go a step further — using actual AI to automatically understand what is in the photos, who is in them, and what text appears in them. The backend for this project is built entirely on Django, which was a course requirement but also turned out to be a great fit for this kind of REST API work.

The system was originally designed with an AWS Amplify-based backend, using DynamoDB and Lambda functions. But that approach had several issues — complex multi-step uploads, client-side search that scanned all data, and a tight dependency on AWS Cognito for auth. The rebuild using Django simplifies all of that significantly.

### Problem Statement

Managing a large collection of personal photos is genuinely inconvenient without intelligent tools. Searching through hundreds of photos manually to find one where a specific person appears, or where a certain text is visible, is not practical. Existing free solutions either don't offer face grouping, or require cloud subscriptions. And, the previous AWS Amplify implementation of this project had a number of architectural issues that made it unreliable — specifically, a 3-step upload process, client-side text search that loaded all photos to device, and JSON type mismatches in face data storage.

So, the problem this project addresses is: how do you build a clean, simple backend that accepts photo uploads, automatically runs face detection and OCR, clusters faces into person profiles, and allows searching — all without heavy infrastructure?

### Objectives

- Build a REST API backend using Django that handles photo uploads with automatic ML analysis
- Integrate AWS Rekognition for face detection, face indexing, face search, and OCR
- Implement a face clustering algorithm that groups the same person across multiple photos
- Use AWS S3 for persistent photo storage with presigned URL access
- Implement JWT-based stateless authentication
- Replace the old 3-step Amplify upload flow with a single endpoint
- Move text search to the server side instead of the client
- Keep the stack minimal — no Celery, no Redis, no complex infrastructure

---

## Literature / Existing System

### Current Solutions and Related Work

Several photo management solutions already exist, both commercial and open-source. Google Photos is probably the most well-known — it offers face grouping, text search, and location-based album creation. Apple Photos does similar things but only on Apple hardware. Amazon Photos also provides some of these features for Prime subscribers.

On the research side, there is quite a lot of published work on face recognition systems, OCR engines, and photo management architectures. The table below summarizes some of the relevant existing systems:

| System / Work | Approach | Limitation |
|---|---|---|
| Google Photos | Proprietary ML, device + cloud | Closed source, requires Google account |
| Apple Photos | On-device ML (Core ML) | Apple ecosystem only |
| Amazon Photos | Cloud-based, S3 storage | Paid/Prime only, no custom API |
| DeepFace (library) | Open source face recognition | Requires own ML infra and training data |
| Tesseract OCR | Open source OCR engine | No face detection, lower accuracy vs cloud |
| Face++ API | Face detection as a service | Third-party dependency, cost at scale |

### Limitations of Existing Systems

So the main issue with existing systems is they are either completely closed (Google, Apple) or they require significant machine learning infrastructure to set up yourself. For a project like this, training a face recognition model from scratch is not feasible. And the open source options like DeepFace or Tesseract don't give you the kind of managed service reliability you get from AWS.

Also, none of the existing academic implementations we found handled the full pipeline — upload, ML analysis, face clustering, OCR, and REST API — in a single lightweight Django application. Most are either just ML demos or full commercial products. There is a clear gap for a clean educational implementation that shows how these things connect.

---

## Proposed System

### Description of the Solution

PhotoSense proposes a Django-based REST API backend that wraps AWS Rekognition and S3 into a clean, minimal set of endpoints. The core idea is: user uploads a photo through one API call, and the backend handles everything else — storing the file in S3, running face detection and OCR through Rekognition, saving the results in a database, and grouping detected faces with known person profiles.

Instead of that, the client (currently being tested via curl/Postman) just sends one multipart POST request and gets back a full JSON response with all the detected faces, text, and metadata.

### Key Features and Advantages

- **Single-endpoint upload**: One `POST /api/photos/upload/` does everything. No multi-step pre-signed URL dance.
- **Automatic face clustering**: Each uploaded photo's faces are compared against a Rekognition collection. If a match is found, the face is linked to an existing Person profile. If not, a new Person is created.
- **Server-side OCR search**: Search is done with a Django ORM `icontains` query on the `detected_text` JSON field — no client-side scanning.
- **JWT Authentication**: Stateless, mobile-friendly, no session management overhead.
- **Dual database support**: SQLite locally for zero-config development, PostgreSQL on Render for production.
- **Person merge**: If Rekognition misclassifies two photos of the same person as different people, users can merge the two person profiles.
- **Django Admin**: Free admin UI at `/admin` for inspecting all database records during development.
- **Minimal stack**: No Celery, no Redis, no message queue. Rekognition runs synchronously (~3-7 seconds per upload, acceptable at this scale).

---

## System Design

### Architecture

The overall system architecture follows a straightforward client → Django backend → AWS services pattern:

```
Client (curl / Postman / Flutter app — in progress)
         |
         | REST API (JWT Auth)
         v
  Django REST Framework
    |             |
    |             |
  PostgreSQL    boto3 ──► AWS S3       (photo storage)
  (SQLite       boto3 ──► Rekognition  (face detect + OCR)
  locally)
```

The Flutter frontend is currently being developed separately and is not included in the current implementation. The backend is fully functional and tested independently.

### Database Schema (ER Diagram)

```
auth_user
  ├── id (PK, int)
  ├── username (email)
  └── password (PBKDF2 hash)
         |
         | 1-to-many
         v
photos_photo                        photos_person
  ├── id (UUID, PK)                   ├── id (UUID, PK)
  ├── owner_id (FK → auth_user)       ├── owner_id (FK → auth_user)
  ├── s3_key                          ├── name
  ├── face_ids (JSON)                 ├── face_id
  ├── detected_text (JSON)            ├── face_ids (JSON)
  ├── detected_faces (JSON)           ├── bounding_box (JSON)
  ├── faces_count                     ├── thumbnail_s3_key
  ├── analyzed_at                     ├── is_unnamed
  └── created_at                      └── created_at
         \                                    /
          \                                  /
           ──────► photos_photoperson ◄──────
                     ├── id (UUID, PK)
                     ├── photo_id (FK)
                     ├── person_id (FK)
                     ├── owner_id (FK)
                     └── UNIQUE(photo_id, person_id)
```

### Use Case Diagram (Textual)

Primary actor: **Authenticated User**

- User registers → `POST /api/auth/register/`
- User logs in → `POST /api/auth/login/` → receives JWT tokens
- User uploads photo → `POST /api/photos/upload/` → system runs ML analysis automatically
- User lists photos → `GET /api/photos/`
- User searches photos by text → `GET /api/photos/search/?q=keyword`
- User views person profiles → `GET /api/persons/`
- User renames a person → `PATCH /api/persons/{id}/`
- User merges two persons → `POST /api/persons/{id}/merge/`
- User deletes a photo → `DELETE /api/photos/{id}/` (also deletes from S3)

### Sequence: Photo Upload Flow

```
Client          Django View        S3           Rekognition       Database
  |                  |              |                |                 |
  |-- POST upload -->|              |                |                 |
  |                  |-- upload --->|                |                 |
  |                  |<-- ok -------|                |                 |
  |                  |-- index_faces (bytes) ------->|                 |
  |                  |<-- face_ids, bboxes ----------|                 |
  |                  |-- detect_text (bytes) ------->|                 |
  |                  |<-- text lines ----------------|                 |
  |                  |-- create Photo record ----------------------->  |
  |                  |-- _cluster_face() for each face               |  |
  |                  |   (search_faces → find/create Person)         |  |
  |                  |-- create PhotoPerson links ------------------->|  |
  |<-- 201 JSON -----| (photo + faces + text)                           |
```

---

## Methodology

### Technologies Used

| Layer | Technology | Purpose |
|---|---|---|
| Backend Framework | Django 4.2 + DRF | REST API, ORM, Admin |
| Authentication | djangorestframework-simplejwt | JWT token generation and validation |
| ML / AI | AWS Rekognition (boto3) | Face detection, face indexing, OCR |
| File Storage | AWS S3 (boto3) | Photo persistence, presigned URLs |
| Database (dev) | SQLite | Zero-config local development |
| Database (prod) | PostgreSQL on Render | Production deployment |
| Deployment | Render (render.yaml) | Auto-deploy from GitHub |
| CORS | django-cors-headers | Cross-origin support for browser clients |
| Environment | python-dotenv | Local `.env` config management |

**Hardware / Runtime Requirements:**
- RAM: 512 MB minimum (1 GB recommended for Render free tier)
- OS: Any (Linux preferred; tested on Ubuntu/macOS)
- Python: 3.10+
- Editor: VS Code / any text editor
- Testing: DRF Browsable API, curl, Postman

### Workflow / Development Process

The project followed a phased build approach:

1. **Phase 1 — Setup**: Django project init, `settings.py` config (SQLite dev, JWT, CORS, DRF defaults), `requirements.txt`
2. **Phase 2 — Models & Admin**: Wrote `Photo`, `Person`, `PhotoPerson` models; ran migrations; registered in Django Admin
3. **Phase 3 — Auth**: `RegisterView`, wired simplejwt's `TokenObtainPairView` and `TokenRefreshView`
4. **Phase 4 — AWS Layer**: `storage.py` (S3 upload, delete, presigned URL) and `ml.py` (Rekognition face index, text detect, face search); created Rekognition collection via Django shell
5. **Phase 5 — Upload Endpoint**: `PhotoUploadView` with the full 8-step flow and `_cluster_face()` algorithm
6. **Phase 6 — CRUD + Search**: `PhotoViewSet`, `PersonViewSet` with merge action; serializers with presigned URL injection
7. **Phase 7 — Deploy**: `render.yaml` written, pushed to GitHub, connected on Render with production PostgreSQL

---

## Implementation

### Module Descriptions

**`photos/models.py` — Data Models**

Three models are defined here. `Photo` stores all metadata about an uploaded image, including the S3 key where the file lives and the JSON results from Rekognition. `Person` represents a unique individual detected across photos — it holds a list of all face IDs Rekognition assigned to that person over time. And `PhotoPerson` is a join table connecting photos and persons in a many-to-many relationship, with a `unique_together` constraint to prevent duplicate links.

**`photos/ml.py` — Rekognition Wrapper**

This module wraps three Rekognition API calls. `index_faces()` sends image bytes to Rekognition, which adds the faces to a collection and returns face IDs with bounding boxes and confidence scores. `detect_text()` runs OCR on the image and returns text lines with confidence above 80%. And `search_faces()` takes a face ID and looks for similar faces in the collection using a 90% similarity threshold. Rekognition receives image bytes directly — it does not need S3 access, which simplifies IAM permissions.

**`photos/storage.py` — S3 Wrapper**

Handles uploading files to S3 with `put_object`, deleting with `delete_object`, and generating 7-day presigned URLs for private bucket access. S3 key format is `photos/{user_id}/{uuid}.{ext}` so files are namespaced per user.

**`photos/views.py` — API Views**

`PhotoUploadView` is the most complex endpoint. It reads the uploaded file, runs both Rekognition calls, saves the Photo record, and then calls `_cluster_face()` for each detected face. `PhotoViewSet` and `PersonViewSet` handle standard CRUD with owner-scoped querysets — no user can query another user's data. The `merge` action on PersonViewSet combines two person profiles by merging their `face_ids` lists and re-linking all `PhotoPerson` records.

**`photos/auth_views.py` — Registration**

A simple `RegisterView` that creates a Django User with email stored as the username field. Password is hashed automatically by Django's `create_user()` using PBKDF2 with 600,000 iterations. simplejwt's `TokenObtainPairView` handles login without any custom serializer needed.

**`photos/serializers.py` — DRF Serializers**

`PhotoSerializer` injects a presigned URL at serialization time via `get_url()` so clients always get a ready-to-use image link. `PersonSerializer` similarly generates a `thumbnail_url` and optionally includes the person's photos list (only on detail view to avoid N+1).

### API Endpoints Reference

```
Auth
  POST  /api/auth/register/          {email, password}
  POST  /api/auth/login/             {username: email, password} → {access, refresh}
  POST  /api/auth/refresh/           {refresh} → {access}

Photos
  POST  /api/photos/upload/          multipart file → runs ML → returns Photo JSON
  GET   /api/photos/                 list (owner-scoped, newest first)
  GET   /api/photos/{id}/            single photo detail
  DELETE /api/photos/{id}/           deletes DB record + S3 file
  GET   /api/photos/search/?q=text   server-side OCR text search

Persons
  GET   /api/persons/                list all persons
  GET   /api/persons/{id}/           person detail + their photos
  PATCH /api/persons/{id}/           rename: {name, is_unnamed: false}
  DELETE /api/persons/{id}/          delete person cluster
  POST  /api/persons/{id}/merge/     {merge_into_id} → merges two profiles
```

### Face Clustering Algorithm

This is the core logic of the project. For each face detected in an uploaded photo:

1. The face is indexed in Rekognition's collection via `index_faces()` — this returns a `face_id`
2. `search_faces()` is called with that `face_id` to find any existing similar face in the collection (90% threshold)
3. If a match is found, the database is queried for a `Person` who has that matched `face_id` in their `face_ids` JSON list
4. If found, the new `face_id` is appended to that person's `face_ids` list
5. If no match or no existing person, a new `Person` is created with `is_unnamed=True`
6. A `PhotoPerson` record is created (or fetched if it already exists) to link this photo to the person

```python
# Core clustering logic (simplified)
def _cluster_face(face, photo, user):
    face_id = face['face_id']
    matched_id = search_faces(face_id)
    person = None

    if matched_id:
        person = Person.objects.filter(
            owner=user, face_ids__contains=matched_id
        ).first()
        if person and face_id not in person.face_ids:
            person.face_ids.append(face_id)
            person.save(update_fields=['face_ids', 'updated_at'])

    if not person:
        person = Person.objects.create(
            owner=user, name='Unknown Person',
            face_id=face_id, face_ids=[face_id],
            bounding_box=face['bounding_box'],
            thumbnail_s3_key=photo.s3_key, is_unnamed=True
        )
    PhotoPerson.objects.get_or_create(
        photo=photo, person=person, defaults={'owner': user}
    )
```

---

## Results & Output

### Working System — CLI Demo

The system is fully functional and all endpoints were tested via curl and the DRF Browsable API. Below is a walkthrough of the main flow:

**Step 1 — Register a user:**
```bash
curl -X POST http://localhost:8000/api/auth/register/ \
  -H "Content-Type: application/json" \
  -d '{"email": "user@example.com", "password": "securepass123"}'
# Response: {"message": "account created"}
```

**Step 2 — Login and get JWT token:**
```bash
curl -X POST http://localhost:8000/api/auth/login/ \
  -H "Content-Type: application/json" \
  -d '{"username": "user@example.com", "password": "securepass123"}'
# Response: {"access": "eyJ0eXA...", "refresh": "eyJ0eXA..."}
```

**Step 3 — Upload a photo:**
```bash
curl -X POST http://localhost:8000/api/photos/upload/ \
  -H "Authorization: Bearer <access_token>" \
  -F "file=@photo.jpg"
# Response: full Photo JSON with detected faces, text, presigned URL
```

**Step 4 — View detected persons:**
```bash
curl http://localhost:8000/api/persons/ \
  -H "Authorization: Bearer <access_token>"
# Response: list of Person objects, each with face_ids and thumbnail_url
```

**Step 5 — Search by text:**
```bash
curl "http://localhost:8000/api/photos/search/?q=exit" \
  -H "Authorization: Bearer <access_token>"
# Returns photos where OCR detected the word "exit"
```

### Sample API Response — Photo Upload

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "s3_key": "photos/1/abc123.jpg",
  "url": "https://s3.amazonaws.com/bucket/photos/1/abc123.jpg?X-Amz-...",
  "faces_count": 2,
  "face_ids": ["face-id-1", "face-id-2"],
  "detected_text": ["Exit Sign", "Floor 3"],
  "detected_faces": [
    {"face_id": "face-id-1", "confidence": 99.8, "bounding_box": {...}},
    {"face_id": "face-id-2", "confidence": 98.4, "bounding_box": {...}}
  ],
  "analyzed_at": "2026-04-22T10:30:00Z",
  "created_at": "2026-04-22T10:30:07Z"
}
```

### Output Explanation

- After upload, two Person records are automatically created (or matched to existing ones)
- The `url` field is a 7-day presigned S3 URL — no manual S3 setup needed on the client side
- `detected_text` can be used immediately for search — the field is queryable with `icontains`
- Django Admin at `/admin` shows all three model tables for easy inspection during development

---

## Conclusion

So this project basically shows how a Django REST Framework backend can integrate with AWS cloud services to build something quite useful — an intelligent photo management API. The architecture is intentionally minimal: one Django process, no background workers, no message queues. And it still delivers face detection, OCR, face clustering, and full CRUD for a small-scale use case.

The main achievement is replacing a complex, bug-prone Amplify/Lambda backend with a clean, readable Django codebase that does the same things more reliably. The face clustering algorithm in particular is a core contribution — it handles the Rekognition collection, the similarity search, and the Person lifecycle all in one small function. Server-side text search was also a notable fix over the previous client-side approach.

---

## Future Scope

There are a few directions this project can go from here. The Flutter mobile frontend is currently in development and once integrated, the full end-to-end mobile experience will be complete. Beyond that:

- **Scalability**: For more than a handful of users, Celery with Redis can be added to process Rekognition calls asynchronously so uploads return immediately with a task ID
- **Face splitting**: Currently only merge is supported. A split operation (separating misclassified faces) would be a useful addition
- **Albums / collections**: Users could organize photos into albums manually or have them auto-generated based on date, location (if EXIF data is parsed), or detected person
- **CDN delivery**: Instead of S3 presigned URLs, a CloudFront CDN distribution would give faster image loading globally
- **GIN indexes**: On PostgreSQL, adding a GIN index on the `face_ids` JSONField would improve the `face_ids__contains` query performance at scale
- **Multi-modal search**: Combining text search with face-based filtering (e.g., "photos of John with text 'birthday'") would make the search experience much more powerful
- **Mobile notifications**: Push notifications when batch uploads complete or when new persons are detected

---

## References

1. Django Documentation — https://docs.djangoproject.com/en/4.2/
2. Django REST Framework — https://www.django-rest-framework.org/
3. djangorestframework-simplejwt — https://django-rest-framework-simplejwt.readthedocs.io/
4. AWS Rekognition Developer Guide — https://docs.aws.amazon.com/rekognition/latest/dg/what-is.html
5. AWS S3 Developer Guide — https://docs.aws.amazon.com/AmazonS3/latest/userguide/
6. boto3 Documentation — https://boto3.amazonaws.com/v1/documentation/api/latest/index.html
7. RFC 7519 — JSON Web Token (JWT) Standard — https://datatracker.ietf.org/doc/html/rfc7519
8. dj-database-url — https://github.com/jazzband/dj-database-url
9. Render Deployment Docs — https://render.com/docs/deploy-django
10. PBKDF2 Key Derivation — NIST SP 800-132 — https://csrc.nist.gov/publications/detail/sp/800-132/final

---

## Appendix

### A. Project File Structure

```
photosense_backend/
├── manage.py
├── requirements.txt
├── .env.example
├── render.yaml
├── photosense/
│   ├── settings.py
│   ├── urls.py
│   └── wsgi.py
└── photos/
    ├── models.py
    ├── serializers.py
    ├── views.py
    ├── auth_views.py
    ├── urls.py
    ├── ml.py
    ├── storage.py
    └── admin.py
```

### B. Environment Variables

```bash
SECRET_KEY=your-django-secret-key
DEBUG=True
AWS_ACCESS_KEY_ID=your-access-key
AWS_SECRET_ACCESS_KEY=your-secret-key
AWS_REGION=ap-south-1
S3_BUCKET_NAME=your-s3-bucket-name
REKOGNITION_COLLECTION_ID=photosense-faces
# DATABASE_URL=postgres://... (set on Render; omit locally for SQLite)
```

### C. Local Setup Commands

```bash
cd photosense_backend
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env        # fill in AWS credentials
python manage.py migrate
python manage.py createsuperuser
python manage.py runserver
```

### D. Rekognition Collection Setup (one-time)

```bash
python manage.py shell -c "from photos.ml import ensure_collection; ensure_collection()"
```

---

*Signed By: Faculty*

---
