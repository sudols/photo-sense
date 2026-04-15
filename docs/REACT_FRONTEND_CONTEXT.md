# PhotoSense — React Frontend Context Document

## Quick Overview

PhotoSense is an AI-powered photo gallery that automatically detects and clusters faces, extracts text via OCR, and makes photos searchable by visual content. Users upload photos, AWS Rekognition handles the AI, and the Django backend serves it all via a REST API.

The project was originally built with a Flutter mobile frontend. This document supports the React web frontend replacement.

**One-liner:** Upload a photo → it's auto-analyzed for faces and text → faces are clustered into "Persons" → you can name them, merge them, and search your photos by detected text.

---

## System Architecture

```
┌─────────────────┐     REST + JWT      ┌──────────────────┐     boto3      ┌──────────────┐
│  React Frontend  │ ──────────────────► │  Django Backend   │ ─────────────► │  Amazon S3   │
│  (Vite, :5173)  │ ◄────────────────── │  (Gunicorn, :8000)│                │  (Photos)    │
└─────────────────┘     JSON            └───────┬──────────┘                └──────────────┘
                                                  │  boto3                      ▲
                                                  ▼                             │
                                          ┌──────────────┐                     │
                                          │  Amazon      │ ──── index_faces ──┘
                                          │  Rekognition │ ──── detect_text ──┘
                                          │  (AI/ML)     │ ──── search_faces ──
                                          └──────────────┘
                                                  ▲
                                          ┌───────┴──────────┐
                                          │  PostgreSQL /    │
                                          │  SQLite          │
                                          │  (Models: Photo, │
                                          │   Person,        │
                                          │   PhotoPerson)   │
                                          └─────────────────┘
```

---

## Backend Tech Stack

| Component | Technology | Notes |
|---|---|---|
| Web framework | Django 4.2+ | Plain Django Views (not DRF ViewSets) |
| Auth | djangorestframework-simplejwt | Access token: 1 day, Refresh: 30 days |
| CORS | django-cors-headers | `CORS_ALLOW_ALL_ORIGINS = DEBUG` (prod fix needed) |
| Database | SQLite (dev) / PostgreSQL (prod via dj-database-url) | |
| Photo storage | Amazon S3 (raw boto3) | Presigned URLs with 7-day expiry |
| Face detection | Amazon Rekognition (raw boto3) | index_faces, detect_text, search_faces |
| Deployment | Render.com (gunicorn) | render.yaml in backend/ |
| CSRF | Exempt on all API views | Mobile-first design, no session auth |

**Notable:** The backend does NOT use Django REST Framework's serializers, viewsets, or routers. It uses plain `django.views.View` classes with manual `JsonResponse` and hand-written `photo_to_dict()` / `person_to_dict()` helpers. This is intentional simplicity.

---

## Database Schema

### Photo
| Field | Type | Description |
|---|---|---|
| id | UUID (PK) | Auto-generated |
| owner | FK → User | The user who uploaded it |
| s3_key | CharField(500) | S3 object path: `photos/{user_id}/{uuid}.jpg` |
| face_ids | JSONField (list) | Rekognition FaceIds found in this photo |
| detected_text | JSONField (list) | OCR text lines (confidence > 80%, type=LINE) |
| detected_faces | JSONField (list) | `[{face_id, bounding_box, confidence}]` per face |
| faces_count | IntegerField | Number of detected faces |
| analyzed_at | DateTimeField (nullable) | When Rekognition finished |
| created_at | DateTimeField | Auto-set on creation |
| updated_at | DateTimeField | Auto-updated on save |

### Person
| Field | Type | Description |
|---|---|---|
| id | UUID (PK) | Auto-generated |
| owner | FK → User | The user who owns this person |
| name | CharField(255) | Default: "Unknown Person" |
| face_id | CharField(100) | Primary/first Rekognition FaceId |
| face_ids | JSONField (list) | All FaceIds clustered into this person |
| bounding_box | JSONField (nullable) | `{Left, Top, Width, Height}` from Rekognition |
| thumbnail_s3_key | CharField(500) | S3 key of the photo used as thumbnail |
| is_unnamed | BooleanField | True until user names the person |
| created_at | DateTimeField | |
| updated_at | DateTimeField | |

### PhotoPerson (junction table)
| Field | Type | Description |
|---|---|---|
| id | UUID (PK) | Auto-generated |
| photo | FK → Photo | |
| person | FK → Person | |
| owner | FK → User | |
| created_at | DateTimeField | |

**Relationships:**
- User → Photo: 1:N (owns)
- User → Person: 1:N (owns)
- Photo ↔ Person: M:N (via PhotoPerson, unique together on photo+person)

---

## API Endpoints

### Authentication

| # | Method | URL | Request Body | Response |
|---|---|---|---|---|
| 1 | POST | `/api/auth/register/` | `{email, password}` | `201: {message: "account created"}` |
| 2 | POST | `/api/auth/login/` | `{username, password}` | `200: {access, refresh}` |
| 3 | POST | `/api/auth/refresh/` | `{refresh}` | `200: {access}` |

**Note on login:** The `username` field in the login request is the user's email. The Django User model uses `username=email` (set during registration).

**Auth flow:** All endpoints below require `Authorization: Bearer <access_token>` header.

### Photos

| # | Method | URL | Request | Response |
|---|---|---|---|---|
| 4 | POST | `/api/photos/upload/` | multipart/form-data with `file` field | `201: Photo JSON` |
| 5 | GET | `/api/photos/` | — | `200: [Photo JSON]` |
| 6 | GET | `/api/photos/<uuid>/` | — | `200: Photo JSON` |
| 7 | DELETE | `/api/photos/<uuid>/` | — | `204: {message: "Photo deleted"}` |
| 8 | GET | `/api/photos/search/?q=<text>` | — | `200: [Photo JSON]` |

### Persons

| # | Method | URL | Request | Response |
|---|---|---|---|---|
| 9 | GET | `/api/persons/` | — | `200: [Person JSON]` (photos=null) |
| 10 | GET | `/api/persons/<uuid>/` | — | `200: Person JSON` (photos=[...]) |
| 11 | PATCH | `/api/persons/<uuid>/` | `{name}` and/or `{is_unnamed}` | `200: Person JSON` (photos=[...]) |
| 12 | DELETE | `/api/persons/<uuid>/` | — | `204: {message: "Person deleted"}` |
| 13 | POST | `/api/persons/<uuid>/merge/` | `{merge_into_id}` | `200: Person JSON` |

---

## API Response Shapes

### Photo JSON
```json
{
  "id": "uuid-string",
  "s3_key": "photos/1/abc123.jpg",
  "url": "https://s3.amazonaws.com/bucket/photos/1/abc123.jpg?presigned-params...",
  "face_ids": ["face-id-1", "face-id-2"],
  "detected_text": ["Hello World", "Sign Text"],
  "detected_faces": [
    {
      "face_id": "face-id-1",
      "bounding_box": {"Left": 0.1, "Top": 0.2, "Width": 0.3, "Height": 0.4},
      "confidence": 99.9
    }
  ],
  "faces_count": 2,
  "analyzed_at": "2025-04-16T10:00:00Z",
  "created_at": "2025-04-16T10:00:00Z",
  "updated_at": "2025-04-16T10:00:00Z"
}
```

**Important:** The `url` field is a presigned S3 URL with 7-day expiry. Use it directly as `<img src={photo.url}>`. It is generated server-side on every request (no client-side S3 interaction).

### Person JSON (list view — `include_photos=false`)
```json
{
  "id": "uuid-string",
  "name": "Unknown Person",
  "face_id": "primary-face-id",
  "face_ids": ["face-id-1", "face-id-2"],
  "bounding_box": {"Left": 0.1, "Top": 0.2, "Width": 0.3, "Height": 0.4},
  "thumbnail_s3_key": "photos/1/abc123.jpg",
  "thumbnail_url": "https://s3.amazonaws.com/...?presigned-params...",
  "is_unnamed": true,
  "created_at": "2025-04-16T10:00:00Z",
  "updated_at": "2025-04-16T10:00:00Z",
  "photos": null
}
```

### Person JSON (detail view — `include_photos=true`)
```json
{
  "id": "uuid-string",
  "name": "John Doe",
  "face_id": "...",
  "face_ids": ["..."],
  "bounding_box": {...},
  "thumbnail_s3_key": "...",
  "thumbnail_url": "https://...",
  "is_unnamed": false,
  "created_at": "...",
  "updated_at": "...",
  "photos": [
    { /* Photo JSON */ },
    { /* Photo JSON */ }
  ]
}
```

### Error Responses
All errors follow the format: `{"error": "description"}` with appropriate HTTP status codes (400, 401, 404).

---

## Core Flows

### Photo Upload (the main flow)
1. User selects photo(s) in the UI
2. Frontend sends `POST /api/photos/upload/` with multipart/form-data (`file` field) + JWT Bearer token
3. Django reads image bytes into memory
4. **Step 1:** Upload raw bytes to S3 via `put_object`
5. **Step 2:** Face detection via Rekognition `index_faces` (from memory, not S3)
6. **Step 3:** Text extraction via Rekognition `detect_text` (from memory, not S3)
7. **Step 4:** Save Photo record to database
8. **Step 5:** Face clustering — for each detected face:
   - Call `search_faces(face_id)` — searches Rekognition collection (vector similarity, 90% threshold)
   - If match found: append face_id to existing Person
   - If no match: create new Person named "Unknown Person"
   - Create PhotoPerson link record
9. **Step 6:** Return response with presigned URL

**Timing:** Synchronous, ~3-7 seconds total. The frontend should show a loading state during upload.

### Face Clustering Algorithm
Located in `backend/photos/views.py:129-158` (`_cluster_face()` function):
1. For each detected face in a photo, call `search_faces(face_id)`
2. If a matching face (≥90% similarity) is found in the Rekognition collection:
   - Find the Person who owns that matched face_id
   - Add the new face_id to that Person's `face_ids` list
3. If no match:
   - Create a new Person with name "Unknown Person", `is_unnamed=True`
   - Set the detected face's bounding box and the photo's S3 key as thumbnail
4. Create a PhotoPerson record linking the photo and person

### Person Merge
1. User initiates merge from person detail page
2. Frontend sends `POST /api/persons/<from_id>/merge/` with `{merge_into_id: <to_id>}`
3. Backend combines `face_ids` from both persons (deduped)
4. Re-links all PhotoPerson records from `from_person` to `to_person`
5. Deletes `from_person`
6. Returns the merged `to_person` with their photos

---

## Auth Implementation Details

### Registration
- Endpoint: `POST /api/auth/register/`
- Body: `{email, password}`
- Creates Django User with `username=email, email=email`
- Returns: `201 {message: "account created"}`
- No tokens returned — user must login after registering

### Login
- Endpoint: `POST /api/auth/login/`
- Body: `{username: email, password}` — note: field is `username` but value is email
- Returns: `{access: "...", refresh: "..."}`
- Access token expires in 1 day
- Refresh token expires in 30 days

### Token Refresh
- Endpoint: `POST /api/auth/refresh/`
- Body: `{refresh: "..."}`
- Returns: `{access: "..."}`
- The frontend should intercept 401 responses and attempt a refresh before logging out

### Per-User Data Isolation
- All querysets filter by `owner=request.user`
- A user can only see/manage their own photos and persons
- Enforced at the View level, not model level

---

## Key Files in Backend

| File | Purpose |
|---|---|
| `backend/photosense/settings.py` | Django settings, JWT config, CORS config |
| `backend/photosense/urls.py` | Root URL config (includes auth + photos urls) |
| `backend/photos/views.py` | All views: AuthenticatedView, PhotoUploadView, PhotoListView, PhotoDetailView, PhotoSearchView, PersonListView, PersonDetailView, PersonMergeView |
| `backend/photos/auth_views.py` | RegisterView only |
| `backend/photos/urls.py` | Photo and Person URL patterns |
| `backend/photos/models.py` | Photo, Person, PhotoPerson models |
| `backend/photos/ml.py` | AWS Rekognition wrappers: index_faces, detect_text, search_faces, ensure_collection |
| `backend/photos/storage.py` | AWS S3 wrappers: upload_to_s3, delete_from_s3, get_presigned_url |
| `backend/requirements.txt` | Python dependencies |
| `backend/render.yaml` | Render.com deployment config |

---

## Known Issues / Tech Debt (from existing TRACKING.md)

These are existing backend issues. The React frontend should work around them:

1. **`CORS_ALLOW_ALL_ORIGINS = DEBUG`** — In production (DEBUG=False), no origins are allowed. A web browser will block all requests. **This MUST be fixed for the React frontend.**
2. **No pagination** — All list endpoints return everything. Fine for demo scale.
3. **`ensure_collection()` never called automatically** — The Rekognition collection must exist before uploads work. Must be run manually or via management command.
4. **`search_faces()` swallows exceptions** — Returns None on any error, which silently creates duplicate "Unknown Person" entries instead of clustering.
5. **`ALLOWED_HOSTS = ["*"]`** — Should be tightened for production.
6. **No token refresh in Flutter app** — The React frontend should handle this properly.
7. **Upload is synchronous** — 3-7 second blocking request. Show loading state on frontend.
8. **No password validation in RegisterView** — Only checks for non-empty email/password.
9. **Orphan persons on photo delete** — Deleting a photo doesn't clean up associated Person/PhotoPerson records.
10. **`PersonDetailView.patch()` returns full person with all photos** — Acceptable for demo scale.

---

## Environment Variables

The backend expects these environment variables (see `backend/.env.example` and `render.yaml`):

| Variable | Example | Required |
|---|---|---|
| SECRET_KEY | random string | Yes |
| DEBUG | True/False | Yes |
| DATABASE_URL | postgres://... | Prod only |
| AWS_ACCESS_KEY_ID | AKIA... | Yes |
| AWS_SECRET_ACCESS_KEY | ... | Yes |
| AWS_REGION | ap-south-1 | Yes |
| S3_BUCKET_NAME | photosense-photos | Yes |
| REKOGNITION_COLLECTION_ID | photosense-faces | Yes |

For the React frontend, the only configuration needed is the backend API base URL.

---

## UML Diagrams

All UML diagrams are in `docs/uml/` as Mermaid (`.mmd`) files:
- `architecture.mmd` — High-level 4-layer system architecture
- `component-architecture.mmd` — Detailed Django internals
- `sequence.mmd` — Photo upload sequence diagram (most detailed)
- `use-case.mmd` — 18 use cases (13 User, 5 System)
- `entity-relation.mmd` — ER diagram for all 4 entities
