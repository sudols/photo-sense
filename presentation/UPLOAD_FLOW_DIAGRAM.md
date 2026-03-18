# Photo Upload Flow - Visual Diagram

## Complete Upload Process

```
┌─────────────────────────────────────────────────────────────────────┐
│                    PHOTO UPLOAD WORKFLOW                             │
│                   (3-7 seconds total time)                          │
└─────────────────────────────────────────────────────────────────────┘

┌──────────────┐
│ Flutter App  │ 
│ User uploads │
│ photo file   │
└──────┬───────┘
       │ HTTP POST /api/photos/upload/
       │ (multipart/form-data)
       ▼
┌──────────────────────────────────────────────────────────────────┐
│  STEP 1: Receive & Validate                                      │
│  ─────────────────────────────                                   │
│  file = request.FILES.get("file")                                │
│  if not file: return error                                       │
│                                                                   │
│  image_bytes = file.read()                                       │
│  s3_key = f"photos/{user.id}/{uuid4()}.jpg"                     │
└──────────────────────┬───────────────────────────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────────────────────────┐
│  STEP 2: Upload to S3                                            │
│  ────────────────────                                            │
│  upload_to_s3(image_bytes, s3_key, content_type)                 │
│                                                                   │
│  ┌─────────────────────────────────────┐                         │
│  │ AWS S3 Bucket                       │                         │
│  │ photos/                             │                         │
│  │ └── {user_id}/                      │                         │
│  │     └── {uuid}.jpg  ← Stored here   │                         │
│  └─────────────────────────────────────┘                         │
└──────────────────────┬───────────────────────────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────────────────────────┐
│  STEP 3: AWS Rekognition - Face Detection                       │
│  ─────────────────────────────────────                           │
│  detected_faces = index_faces(image_bytes)                       │
│                                                                   │
│  ┌────────────────────────────────────────┐                      │
│  │ AWS Rekognition Service                │                      │
│  │ • Detects faces in image                │                     │
│  │ • Stores face vectors in collection     │                     │
│  │ • Returns face IDs + metadata           │                     │
│  └────────────────────────────────────────┘                      │
│                                                                   │
│  Returns:                                                         │
│  [                                                                │
│    {                                                              │
│      "face_id": "abc123",                                         │
│      "bounding_box": {Left: 0.2, Top: 0.3, Width: 0.1, ...},     │
│      "confidence": 99.8                                           │
│    },                                                             │
│    { ... more faces ... }                                         │
│  ]                                                                │
└──────────────────────┬───────────────────────────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────────────────────────┐
│  STEP 4: AWS Rekognition - Text Detection (OCR)                 │
│  ────────────────────────────────────────                        │
│  detected_text = detect_text(image_bytes)                        │
│                                                                   │
│  ┌────────────────────────────────────────┐                      │
│  │ AWS Rekognition Service                │                      │
│  │ • Detects text in image (signs, etc)    │                     │
│  │ • Filters: LINE type, >80% confidence   │                     │
│  │ • Returns list of text strings          │                     │
│  └────────────────────────────────────────┘                      │
│                                                                   │
│  Returns: ["Hello World", "Exit Sign", "Main Street"]            │
└──────────────────────┬───────────────────────────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────────────────────────┐
│  STEP 5: Save Photo Record                                       │
│  ──────────────────────                                          │
│  photo = Photo.objects.create(                                   │
│      owner=request.user,                                         │
│      s3_key=s3_key,                                              │
│      face_ids=["abc123", "def456"],                              │
│      detected_text=["Hello World", "Exit Sign"],                 │
│      detected_faces=[{...}, {...}],                              │
│      faces_count=2,                                              │
│      analyzed_at=now()                                           │
│  )                                                                │
│                                                                   │
│  ┌─────────────────────────────┐                                 │
│  │ PostgreSQL Database         │                                 │
│  │ ┌─────────────────────────┐ │                                 │
│  │ │ Photo Table             │ │                                 │
│  │ │ ├── id: uuid            │ │                                 │
│  │ │ ├── owner_id: 1         │ │                                 │
│  │ │ ├── s3_key: photos/...  │ │                                 │
│  │ │ ├── face_ids: JSON      │ │                                 │
│  │ │ ├── detected_text: JSON │ │                                 │
│  │ │ └── ...                 │ │                                 │
│  │ └─────────────────────────┘ │                                 │
│  └─────────────────────────────┘                                 │
└──────────────────────┬───────────────────────────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────────────────────────┐
│  STEP 6: Face Clustering                                         │
│  ────────────────────                                            │
│  for face in detected_faces:                                     │
│      _cluster_face(face, photo, user)                            │
│                                                                   │
│  For each detected face:                                         │
│                                                                   │
│  ┌────────────────────────────────────────────────────┐          │
│  │ 6a. Search for similar faces                       │          │
│  │ matched_id = search_faces(face_id)                 │          │
│  │                                                     │          │
│  │ AWS Rekognition searches its face collection       │          │
│  │ Returns match if similarity > 90%                  │          │
│  └─────────────────┬──────────────────────────────────┘          │
│                    │                                              │
│                    ▼                                              │
│  ┌────────────────────────────────────────────────────┐          │
│  │ 6b. Find or Create Person record                   │          │
│  │                                                     │          │
│  │ IF match found:                                    │          │
│  │   person = Person.objects.filter(                  │          │
│  │       face_ids__contains=matched_id                │          │
│  │   )                                                 │          │
│  │   person.face_ids.append(new_face_id)              │          │
│  │                                                     │          │
│  │ ELSE (new person):                                 │          │
│  │   person = Person.objects.create(                  │          │
│  │       name="Unknown Person",                       │          │
│  │       face_id=face_id,                             │          │
│  │       face_ids=[face_id],                          │          │
│  │       is_unnamed=True                              │          │
│  │   )                                                 │          │
│  └─────────────────┬──────────────────────────────────┘          │
│                    │                                              │
│                    ▼                                              │
│  ┌────────────────────────────────────────────────────┐          │
│  │ 6c. Link Photo to Person                           │          │
│  │                                                     │          │
│  │ PhotoPerson.objects.get_or_create(                 │          │
│  │     photo=photo,                                   │          │
│  │     person=person,                                 │          │
│  │     owner=user                                     │          │
│  │ )                                                   │          │
│  │                                                     │          │
│  │ ┌───────────────────────────┐                      │          │
│  │ │ Database Tables           │                      │          │
│  │ │                           │                      │          │
│  │ │ Person Table:             │                      │          │
│  │ │ ├── John Doe              │                      │          │
│  │ │ │   face_ids: [a,b,c]     │                      │          │
│  │ │ └── Jane Smith            │                      │          │
│  │ │     face_ids: [x,y]       │                      │          │
│  │ │                           │                      │          │
│  │ │ PhotoPerson Table:        │                      │          │
│  │ │ ├── photo1 ↔ John Doe     │                      │          │
│  │ │ ├── photo2 ↔ John Doe     │                      │          │
│  │ │ └── photo2 ↔ Jane Smith   │                      │          │
│  │ └───────────────────────────┘                      │          │
│  └────────────────────────────────────────────────────┘          │
└──────────────────────┬───────────────────────────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────────────────────────┐
│  STEP 7: Return Response                                         │
│  ───────────────────                                             │
│  response = photo_to_dict(photo)                                 │
│                                                                   │
│  Helper function converts Photo model to JSON:                   │
│  {                                                                │
│    "id": "uuid-here",                                            │
│    "s3_key": "photos/1/abc.jpg",                                 │
│    "url": "https://s3...presigned-url",  ← Generated on-demand   │
│    "face_ids": ["abc123", "def456"],                             │
│    "detected_text": ["Hello World"],                             │
│    "faces_count": 2,                                             │
│    "analyzed_at": "2024-01-01T12:00:00Z",                        │
│    "created_at": "2024-01-01T12:00:00Z"                          │
│  }                                                                │
└──────────────────────┬───────────────────────────────────────────┘
                       │
                       │ JSON Response (HTTP 201)
                       ▼
                 ┌──────────────┐
                 │ Flutter App  │
                 │ Displays     │
                 │ uploaded     │
                 │ photo        │
                 └──────────────┘


═══════════════════════════════════════════════════════════════════
                        KEY DECISIONS
═══════════════════════════════════════════════════════════════════

1. SYNCHRONOUS PROCESSING
   ✓ Pros: Simpler code, immediate feedback
   ✗ Cons: 3-7 second wait time
   → Acceptable for 2-3 users (semester project scale)

2. AWS REKOGNITION COLLECTION
   • Maintains a searchable face database
   • Enables cross-photo face matching
   • 90% similarity threshold (configurable)

3. DATABASE DESIGN
   • Photo stores ML results (no re-analysis needed)
   • Person can have multiple face_ids (same person, different angles)
   • PhotoPerson enables many-to-many queries

4. PRESIGNED URLS
   • S3 bucket is private
   • Generate temporary URLs (7-day expiry)
   • Security: URLs expire, can't guess object keys (UUID-based)

═══════════════════════════════════════════════════════════════════
                      ERROR HANDLING
═══════════════════════════════════════════════════════════════════

• File validation: Check if file exists
• S3 upload: Boto3 handles retries
• Rekognition: If face detection fails, photo still saved (faces_count=0)
• Face clustering: search_faces() wrapped in try/except (graceful degradation)
• Database: Unique constraints prevent duplicate PhotoPerson links

═══════════════════════════════════════════════════════════════════
                    PERFORMANCE NOTES
═══════════════════════════════════════════════════════════════════

• S3 upload: ~500ms
• Face detection: ~2-4s (depends on image size, face count)
• Text detection: ~1-2s
• Face search: ~500ms per face
• Database saves: <100ms

Total: 3-7 seconds for typical photo with 1-3 faces
