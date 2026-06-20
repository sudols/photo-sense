# PhotoSense Backend - Project Showcase

> **Django-based photo management backend with AI-powered face detection and text recognition**

---

## Overview

PhotoSense is a photo management system backend built with Django, featuring:
- **JWT Authentication** - Secure, stateless token-based auth
- **AWS S3 Storage** - Scalable cloud photo storage
- **AWS Rekognition** - AI-powered face detection and OCR
- **Face Clustering** - Automatic person grouping across photos
- **PostgreSQL Database** - Production-ready relational database

---

## Architecture

### Tech Stack
- **Backend Framework**: Django 4.2
- **Authentication**: JWT (djangorestframework-simplejwt)
- **Database**: PostgreSQL (production) / SQLite (development)
- **Cloud Storage**: AWS S3
- **Machine Learning**: AWS Rekognition (Face Detection + OCR)
- **Server**: Gunicorn + WSGI

### System Components
```
┌─────────────────┐
│  Client Layer   │  Mobile/Web HTTP Requests
└────────┬────────┘
         │ REST + JWT (HTTPS)
         ▼
┌─────────────────┐
│  Django Backend │  13 REST API Endpoints
│  - Views        │  Authentication & Authorization
│  - Models       │  Business Logic
│  - ML Module    │  Face Detection & OCR
│  - Storage      │  S3 Integration
└────────┬────────┘
         │
    ┌────┴────┬──────────────┬──────────────┐
    ▼         ▼              ▼              ▼
┌──────┐  ┌──────┐      ┌──────┐      ┌──────┐
│ PostgreSQL │  │  S3  │      │ Rekognition │  
│ Database   │  │ Bucket │    │   (ML)      │
└──────┘  └──────┘      └──────┘      └──────┘
```

---

## Project Structure

```
photo_sense/
├── backend/                    # Django application
│   ├── photosense/            # Project settings
│   │   ├── settings.py        # Configuration (JWT, database, CORS)
│   │   └── urls.py            # Main URL routing
│   ├── photos/                # Main app
│   │   ├── models.py          # Database models (Photo, Person, PhotoPerson)
│   │   ├── views.py           # API endpoints (13 endpoints)
│   │   ├── auth_views.py      # User registration
│   │   ├── ml.py              # AWS Rekognition integration
│   │   ├── storage.py         # AWS S3 integration
│   │   └── urls.py            # API URL patterns
│   ├── requirements.txt       # Python dependencies
│   └── manage.py              # Django management script
├── docs/                      # Documentation
│   └── uml/                   # System diagrams (Mermaid)
└── presentation/              # Showcase documentation
    ├── BACKEND_WALKTHROUGH.md
    ├── AUTH_AND_DATABASE_DEEP_DIVE.md
    ├── UPLOAD_FLOW_DIAGRAM.md
    └── ...
```

---

## Database Schema

**4 Tables** with UUID primary keys:

### User (Django Built-in)
- `id`, `username` (email), `password` (hashed), `email`
- **Password**: PBKDF2 with 600,000 iterations

### Photo
- `id` (UUID), `owner` (FK → User), `s3_key`, `face_ids` (JSON)
- `detected_text` (JSON), `detected_faces` (JSON)
- `faces_count`, `analyzed_at`, `created_at`, `updated_at`

### Person
- `id` (UUID), `owner` (FK → User), `name`, `face_id`, `face_ids` (JSON)
- `bounding_box` (JSON), `thumbnail_s3_key`, `is_unnamed`
- `created_at`, `updated_at`

### PhotoPerson (Join Table)
- `id` (UUID), `photo` (FK → Photo), `person` (FK → Person)
- `owner` (FK → User), `created_at`
- **Constraint**: `unique_together = (photo, person)`

---

## API Endpoints (13 total)

### Authentication (3)
- `POST /api/auth/register/` - User registration
- `POST /api/auth/login/` - Login (returns JWT tokens)
- `POST /api/auth/refresh/` - Refresh access token

### Photos (4)
- `POST /api/photos/upload/` - Upload photo with AI analysis
- `GET /api/photos/` - List user's photos
- `GET /api/photos/<id>/` - Get photo details
- `GET /api/photos/search/?q=text` - Search photos by detected text
- `DELETE /api/photos/<id>/` - Delete photo

### Persons (3)
- `GET /api/persons/` - List detected persons
- `GET /api/persons/<id>/` - Get person details
- `PATCH /api/persons/<id>/` - Rename person
- `POST /api/persons/<id>/merge/` - Merge duplicate persons
- `DELETE /api/persons/<id>/` - Delete person

---

## 🎯 Key Features

### 1. Photo Upload Flow (7 Steps)
1. **File Validation** - Check file type and size
2. **S3 Upload** - Store original image in cloud
3. **Face Detection** - AWS Rekognition indexes faces
4. **Text Detection** - OCR extracts text from image
5. **Database Save** - Create Photo record with ML results
6. **Face Clustering** - Match faces to existing persons (90% threshold)
7. **Response** - Return photo data with presigned URL

### 2. Face Clustering Algorithm
- For each detected face, search AWS collection for matches
- **Match found** → Add face_id to existing Person
- **No match** → Create new Person ("Unknown Person")
- Links Photo ↔ Person via PhotoPerson table
- Result: Same person across photos gets grouped automatically

### 3. Security Features
- **JWT Authentication** - Stateless, mobile-friendly
- **Data Isolation** - All queries filter by `owner=request.user`
- **Password Hashing** - PBKDF2 with 600,000 iterations
- **UUIDs as Primary Keys** - Non-sequential, harder to guess
- **CORS Configuration** - Controlled cross-origin access

---

## Presentation Documentation

Comprehensive guides for project showcase:

1. **BACKEND_WALKTHROUGH.md** - Complete technical walkthrough
2. **AUTH_AND_DATABASE_DEEP_DIVE.md** - Auth & DB architecture
3. **AUTH_DB_VISUAL_DIAGRAMS.md** - Visual flow diagrams
4. **UPLOAD_FLOW_DIAGRAM.md** - Photo upload process
5. **PRESENTATION_QUICK_REF.md** - Quick reference cards
6. **AUTH_DB_PRESENTATION_CHEAT_SHEET.md** - Auth/DB cheat sheet

---

## Setup & Installation

### Prerequisites
- Python 3.10+
- PostgreSQL (production) or SQLite (development)
- AWS Account (S3 + Rekognition)

### Environment Variables
```bash
SECRET_KEY=your-django-secret-key
DEBUG=True  # False in production
DATABASE_URL=postgresql://user:pass@host:5432/dbname  # Optional
AWS_ACCESS_KEY_ID=your-aws-key
AWS_SECRET_ACCESS_KEY=your-aws-secret
AWS_STORAGE_BUCKET_NAME=your-s3-bucket
AWS_REKOGNITION_COLLECTION_ID=your-collection-id
```

### Run Locally
```bash
cd backend
pip install -r requirements.txt
python manage.py migrate
python manage.py createsuperuser
python manage.py runserver
```

Server runs at `http://localhost:8000`

---

## Project Stats

- **Lines of Code**: ~500 (backend only)
- **API Endpoints**: 13
- **Database Tables**: 4
- **AWS Services**: 2 (S3 + Rekognition)
- **Authentication**: JWT (1-day access, 30-day refresh)
- **Password Hashing**: PBKDF2 (600,000 iterations)

---

## Academic Context

This is a **semester project** demonstrating:
- REST API design and implementation
- JWT-based authentication
- Relational database modeling
- Cloud service integration (AWS)
- Machine learning API usage
- Security best practices

**Note**: Built for 2-3 users as a demonstration project, not production-scale deployment.

---

## License

This project is for educational purposes (semester project showcase).
