# PhotoSense Backend - Code Walkthrough for Presentation

> **Presentation Guide**: This document provides a comprehensive walkthrough of the PhotoSense backend for your project showcase.

---

## 📋 Table of Contents
1. [Project Overview](#project-overview)
2. [Architecture & Tech Stack](#architecture--tech-stack)
3. [Database Models](#database-models)
4. [API Endpoints](#api-endpoints)
5. [Deep Dive: Photo Upload Flow](#deep-dive-photo-upload-flow)
6. [AWS Integration](#aws-integration)
7. [Face Clustering Algorithm](#face-clustering-algorithm)
8. [Key Talking Points](#key-talking-points)

---

## 1. Project Overview

**What is PhotoSense?**
- A photo management application with AI-powered face detection and text recognition
- Automatically detects and clusters faces across your photo library
- OCR capability to search photos by text content
- Built with Django backend + Flutter mobile frontend

**Core Features:**
- 📸 Photo upload with automatic face detection
- 👤 Face clustering (groups same person across photos)
- 🔍 Text search using OCR
- 🔐 JWT-based authentication
- ☁️ Cloud storage on AWS S3

---

## 2. Architecture & Tech Stack

### Backend Stack
```
Django 4.2          - Web framework
AWS S3              - Photo storage
AWS Rekognition     - Face detection & OCR
PostgreSQL          - Production database
SQLite              - Development database
JWT                 - Authentication
```

### Project Structure
```
backend/
├── photosense/          # Django project settings
│   ├── settings.py      # Configuration
│   └── urls.py          # Main URL routing
├── photos/              # Main app
│   ├── models.py        # Database models (Photo, Person, PhotoPerson)
│   ├── views.py         # API endpoints (13 endpoints)
│   ├── ml.py            # AWS Rekognition integration
│   ├── storage.py       # AWS S3 integration
│   ├── auth_views.py    # User registration
│   └── urls.py          # API URL patterns
└── manage.py            # Django CLI
```

---

## 3. Database Models

### 3.1 Photo Model
**Purpose**: Stores uploaded photos and their ML analysis results

```python
class Photo(models.Model):
    id = UUIDField              # Unique identifier
    owner = ForeignKey(User)    # Who uploaded it
    s3_key = CharField          # Location in S3 bucket
    
    # ML Analysis Results (from AWS Rekognition)
    face_ids = JSONField        # List of detected face IDs
    detected_text = JSONField   # OCR results (text found in image)
    detected_faces = JSONField  # Face metadata (bounding boxes, confidence)
    faces_count = IntegerField  # How many faces detected
    analyzed_at = DateTimeField # When ML analysis completed
```

**Key Points:**
- Uses UUIDs instead of integers for better security
- Stores ML results directly in database (no need to re-analyze)
- JSONField allows flexible storage of AWS Rekognition data

---

### 3.2 Person Model
**Purpose**: Represents a unique person detected across multiple photos

```python
class Person(models.Model):
    id = UUIDField
    owner = ForeignKey(User)
    name = CharField             # User-assigned name (default: "Unknown Person")
    face_id = CharField          # Primary face ID from AWS
    face_ids = JSONField         # All face IDs for this person (grows over time)
    bounding_box = JSONField     # Face coordinates for thumbnail
    thumbnail_s3_key = CharField # Reference photo for this person
    is_unnamed = BooleanField    # Whether user has named this person
```

**Key Points:**
- One person can have multiple face IDs (same person in different photos)
- Users can rename persons later
- Stores thumbnail reference for UI display

---

### 3.3 PhotoPerson Model
**Purpose**: Many-to-many relationship between Photos and Persons

```python
class PhotoPerson(models.Model):
    photo = ForeignKey(Photo)
    person = ForeignKey(Person)
    owner = ForeignKey(User)
    unique_together = ("photo", "person")  # No duplicates
```

**Why we need this:**
- One photo can have multiple people
- One person appears in multiple photos
- Enables queries like "show all photos of John" or "who's in this photo?"

---

## 4. API Endpoints

### Authentication Endpoints
```
POST /api/auth/register/   - Create new user account
POST /api/auth/login/      - Get JWT access token
POST /api/auth/refresh/    - Refresh expired token
```

### Photo Endpoints
```
POST   /api/photos/upload/      - Upload new photo (triggers ML analysis)
GET    /api/photos/             - List all user's photos
GET    /api/photos/<id>/        - Get single photo details
DELETE /api/photos/<id>/        - Delete photo (also deletes from S3)
GET    /api/photos/search/?q=   - Search photos by text content
```

### Person Endpoints
```
GET    /api/persons/            - List all detected persons
GET    /api/persons/<id>/       - Get person with all their photos
PATCH  /api/persons/<id>/       - Rename a person
DELETE /api/persons/<id>/       - Delete person cluster
POST   /api/persons/<id>/merge/ - Merge two persons (if detected as separate)
```

**Total:** 13 API endpoints

---

## 5. Deep Dive: Photo Upload Flow

### 5.1 Overview
This is the **most complex and interesting** endpoint. When a user uploads a photo:

```
User uploads image → S3 upload → Face detection → Text detection → 
Face clustering → Database save → Return results
```

**Time:** Takes 3-7 seconds (synchronous processing - fine for small scale)

---

### 5.2 Step-by-Step Breakdown

**File:** `backend/photos/views.py` - `PhotoUploadView.post()`

```python
def post(self, request):
    # STEP 1: Receive and validate file
    file = request.FILES.get("file")
    if not file:
        return {"error": "no file provided"}
    
    # STEP 2: Prepare S3 storage path
    image_bytes = file.read()
    s3_key = f"photos/{request.user.id}/{uuid.uuid4()}{ext}"
    
    # STEP 3: Upload to S3
    upload_to_s3(image_bytes, s3_key, content_type)
    
    # STEP 4: Run AWS Rekognition face detection
    detected_faces = index_faces(image_bytes)
    # Returns: [{face_id: "abc123", bounding_box: {...}, confidence: 99.8}]
    
    # STEP 5: Run AWS Rekognition text detection (OCR)
    detected_text = detect_text(image_bytes)
    # Returns: ["Hello World", "Sign: Exit"]
    
    # STEP 6: Save Photo record to database
    photo = Photo.objects.create(
        owner=request.user,
        s3_key=s3_key,
        face_ids=[f["face_id"] for f in detected_faces],
        detected_text=detected_text,
        detected_faces=detected_faces,
        faces_count=len(detected_faces),
        analyzed_at=timezone.now()
    )
    
    # STEP 7: Face clustering - link faces to Person records
    for face in detected_faces:
        _cluster_face(face, photo, request.user)
    
    # STEP 8: Return photo data to client
    return photo_to_dict(photo)
```

---

### 5.3 Face Clustering Logic

**The Problem:**
- AWS Rekognition gives each face a unique ID
- We need to group faces of the same person across multiple photos
- Example: John appears in 5 photos → should create 1 Person with 5 face IDs

**Solution:** `_cluster_face()` function

```python
def _cluster_face(face, photo, user):
    face_id = face["face_id"]
    
    # STEP 1: Search AWS collection for similar faces
    matched_id = search_faces(face_id)  # Uses 90% similarity threshold
    
    # STEP 2: If match found, try to find existing Person
    if matched_id:
        person = Person.objects.filter(
            owner=user,
            face_ids__contains=matched_id
        ).first()
        
        if person:
            # Add this new face_id to existing person
            person.face_ids.append(face_id)
            person.save()
    
    # STEP 3: No match? Create new Person
    if not person:
        person = Person.objects.create(
            owner=user,
            name="Unknown Person",
            face_id=face_id,
            face_ids=[face_id],
            bounding_box=face["bounding_box"],
            thumbnail_s3_key=photo.s3_key,
            is_unnamed=True
        )
    
    # STEP 4: Link this photo to this person
    PhotoPerson.objects.get_or_create(
        photo=photo,
        person=person,
        defaults={"owner": user}
    )
```

**Key Algorithm Points:**
1. Uses AWS Rekognition's `search_faces()` with 90% threshold
2. Maintains a list of all face IDs for each person
3. Automatically creates new Person records for unknown faces
4. Creates PhotoPerson link for querying later

---

## 6. AWS Integration

### 6.1 AWS Rekognition (ml.py)

**Face Detection:**
```python
def index_faces(image_bytes):
    """Add faces to AWS collection and return metadata"""
    response = client.index_faces(
        CollectionId=COLLECTION_ID,
        Image={"Bytes": image_bytes},
        DetectionAttributes=["DEFAULT"]
    )
    # Returns face IDs, bounding boxes, confidence scores
```

**Text Detection (OCR):**
```python
def detect_text(image_bytes):
    """Extract text from image"""
    response = client.detect_text(Image={"Bytes": image_bytes})
    # Filters: LINE type only, >80% confidence
    return [text for text in response if confidence > 80]
```

**Face Search:**
```python
def search_faces(face_id):
    """Find similar faces in collection"""
    response = client.search_faces(
        CollectionId=COLLECTION_ID,
        FaceId=face_id,
        FaceMatchThreshold=90,  # 90% similarity required
        MaxFaces=1
    )
    # Returns best match or None
```

---

### 6.2 AWS S3 (storage.py)

**Upload:**
```python
def upload_to_s3(file_bytes, s3_key, content_type):
    s3_client.put_object(
        Bucket=BUCKET,
        Key=s3_key,
        Body=file_bytes,
        ContentType=content_type
    )
```

**Presigned URLs:**
```python
def get_presigned_url(s3_key, expiry_seconds=604800):  # 7 days
    """Generate temporary URL for private S3 objects"""
    return s3_client.generate_presigned_url(
        'get_object',
        Params={'Bucket': BUCKET, 'Key': s3_key},
        ExpiresIn=expiry_seconds
    )
```

**Why presigned URLs?**
- S3 bucket is private (not publicly accessible)
- Presigned URLs allow temporary access without exposing credentials
- URLs expire after 7 days for security

---

## 7. Other Key Endpoints

### 7.1 Photo Search
**Endpoint:** `GET /api/photos/search/?q=hello`

```python
def get(self, request):
    query = request.GET.get("q", "").strip()
    
    # Search in detected_text field (OCR results)
    photos = Photo.objects.filter(
        owner=request.user,
        detected_text__icontains=query
    )
    
    return [photo_to_dict(p) for p in photos]
```

**Example Use Case:**
- User uploads photo of a street sign saying "Main Street"
- OCR detects "Main Street" and stores in `detected_text`
- User searches "main" → finds this photo

---

### 7.2 Person Merge
**Endpoint:** `POST /api/persons/<id>/merge/`

**Use Case:** Sometimes AWS detects same person as 2 different people

```python
def post(self, request, pk):
    from_person = Person.objects.get(id=pk)
    to_person = Person.objects.get(id=merge_into_id)
    
    # Merge face IDs
    to_person.face_ids = list(set(
        to_person.face_ids + from_person.face_ids
    ))
    to_person.save()
    
    # Move all PhotoPerson links
    PhotoPerson.objects.filter(person=from_person).update(
        person=to_person
    )
    
    # Delete old person
    from_person.delete()
    
    return person_to_dict(to_person)
```

---

### 7.3 Person Detail (with Photos)
**Endpoint:** `GET /api/persons/<id>/`

```python
def get(self, request, pk):
    person = Person.objects.get(id=pk, owner=request.user)
    
    # Include all photos this person appears in
    return person_to_dict(person, include_photos=True)
```

**Response Example:**
```json
{
  "id": "abc-123",
  "name": "John Doe",
  "face_ids": ["face1", "face2", "face3"],
  "is_unnamed": false,
  "photos": [
    {"id": "photo1", "url": "https://s3.../presigned"},
    {"id": "photo2", "url": "https://s3.../presigned"},
    {"id": "photo3", "url": "https://s3.../presigned"}
  ]
}
```

---

## 8. Key Talking Points for Presentation

### 8.1 Technical Highlights

**1. Simplified Architecture (Recent Improvement)**
- Originally used Django REST Framework (DRF) serializers
- Refactored to plain Django views with helper functions
- **Result:** ~100 lines of code removed, easier to understand
- Same functionality, simpler implementation

**2. AWS Integration**
- Uses **AWS Rekognition** for face detection (no training required)
- Maintains a face collection for similarity matching
- **AWS S3** for scalable photo storage
- Presigned URLs for secure image access

**3. Face Clustering Algorithm**
- Automatically groups same person across photos
- 90% similarity threshold prevents false matches
- Handles edge cases (merge functionality for misclassified faces)

**4. Real-time OCR**
- Detects text in images automatically
- Enables search functionality across photo library
- Filters low-confidence detections (>80% only)

**5. Security**
- JWT authentication for all endpoints
- User isolation (can only see own photos)
- Private S3 bucket with temporary access URLs
- UUID primary keys (harder to guess than sequential IDs)

---

### 8.2 Presentation Flow Suggestion

**Opening (1 min):**
- "PhotoSense is a photo management app with AI-powered features"
- "Backend: Django + AWS, Frontend: Flutter"
- "13 API endpoints, 3 database models, AWS integration"

**Database Models (2 mins):**
- Show `models.py` on screen
- Explain Photo, Person, PhotoPerson relationship
- Highlight JSONField usage for ML results

**Main Demo: Photo Upload (5 mins):**
- Walk through the 8-step upload flow
- Show code: `PhotoUploadView.post()`
- Explain face clustering algorithm
- Emphasize the ML integration

**AWS Integration (2 mins):**
- Show `ml.py` and `storage.py`
- Explain Rekognition face detection
- Explain S3 presigned URLs

**Other Features (2 mins):**
- Quickly mention search, merge, CRUD operations
- Show the 13 endpoints list

**Technical Decisions (1 min):**
- Why Django? (Course requirement, but also good for rapid development)
- Why AWS? (Rekognition = no ML training needed)
- Why synchronous? (3-7s is acceptable for 2-3 users)

**Closing:**
- "Questions?"

---

### 8.3 Questions You Might Get

**Q: Why not use background tasks for photo processing?**
A: For 2-3 users, 3-7 second response is acceptable. Adding Celery would increase complexity. It's in the roadmap for production scale.

**Q: How accurate is face detection?**
A: AWS Rekognition has 99%+ accuracy. We use 90% similarity threshold for clustering, which can be adjusted based on user feedback.

**Q: What if two different people look similar?**
A: That's why we have the merge/split functionality. Users can manually correct if the algorithm misclassifies.

**Q: Why Django instead of FastAPI/Flask?**
A: Django was a course requirement. Also provides built-in admin panel, ORM, and authentication out of the box.

**Q: How do you handle large photo libraries?**
A: Currently stores all photos in S3. For scaling, would add pagination, lazy loading, and possibly CDN for image delivery.

**Q: Security concerns with presigned URLs?**
A: URLs expire after 7 days. Even if leaked, limited time window. For production, could reduce to 1 hour or implement signed tokens.

---

## 9. Code Demo Tips

### Show These Files During Presentation:

**1. models.py** (Database structure)
- Clean, well-commented
- Shows the data relationships

**2. views.py - PhotoUploadView** (Main upload flow)
- The most impressive part
- Shows integration of multiple services

**3. ml.py** (AWS Rekognition)
- Short, focused functions
- Shows ML integration

**4. urls.py** (API endpoints)
- Shows all 13 endpoints at a glance

### Don't Show:
- `settings.py` (boring configuration)
- `auth_views.py` (simple registration, nothing special)
- Migration files

---

## 10. Quick Reference

### Commands to Show
```bash
# Show all endpoints
python manage.py check

# Database migrations
python manage.py migrate

# Create admin user
python manage.py createsuperuser

# Run server
python manage.py runserver
```

### File Statistics
- **Total Python files:** 18
- **Lines of code in views.py:** 277
- **Database models:** 3
- **API endpoints:** 13
- **AWS services used:** 2 (S3, Rekognition)

---

## Good Luck! 🚀

**Remember:**
- Focus on the **photo upload flow** (your strength)
- Highlight **AWS integration** (impressive technical aspect)
- Keep it simple - you don't need to memorize every line
- Be honest if you don't know something - "that's a great question, I'd need to research that further"

**Your core message:** "I built a photo app that uses AWS AI to automatically detect faces and text, making photo organization effortless."
