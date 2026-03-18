# Testing the Backend

## ✅ Backend is Ready to Test!

The Django backend is fully functional on the `backend-presentation` branch.

---

## Quick Start

### 1. Activate Virtual Environment
```bash
cd backend
source venv/bin/activate
```

### 2. Run Django Server
```bash
python manage.py runserver
```

Server runs at: **http://localhost:8000**

---

## Test the API

### Using curl

**Register a user:**
```bash
curl -X POST http://localhost:8000/api/auth/register/ \
  -H "Content-Type: application/json" \
  -d '{"email": "test@example.com", "password": "testpass123"}'
```

**Login (get JWT tokens):**
```bash
curl -X POST http://localhost:8000/api/auth/login/ \
  -H "Content-Type: application/json" \
  -d '{"username": "test@example.com", "password": "testpass123"}'
```

**List photos (requires token):**
```bash
curl http://localhost:8000/api/photos/ \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN_HERE"
```

### Using Postman or Thunder Client

1. **Import** the API endpoints
2. **Set Authorization**: Bearer Token
3. **Test** all 13 endpoints

---

## Available Endpoints

### Authentication
- `POST /api/auth/register/` - Create account
- `POST /api/auth/login/` - Get tokens
- `POST /api/auth/refresh/` - Refresh access token

### Photos
- `POST /api/photos/upload/` - Upload photo
- `GET /api/photos/` - List photos
- `GET /api/photos/<id>/` - Photo details
- `GET /api/photos/search/?q=text` - Search by OCR text
- `DELETE /api/photos/<id>/` - Delete photo

### Persons
- `GET /api/persons/` - List detected persons
- `GET /api/persons/<id>/` - Person details
- `PATCH /api/persons/<id>/` - Rename person
- `POST /api/persons/<id>/merge/` - Merge persons
- `DELETE /api/persons/<id>/` - Delete person

---

## Environment Variables

Check `backend/.env` for AWS credentials:
```bash
cat backend/.env
```

Required variables:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_STORAGE_BUCKET_NAME`
- `AWS_REKOGNITION_COLLECTION_ID`

---

## Database

**Default**: SQLite (`backend/db.sqlite3`)

**Migrations** (if needed):
```bash
python manage.py migrate
```

**Create admin user** (for Django admin):
```bash
python manage.py createsuperuser
```

**Access admin panel**: http://localhost:8000/admin/

---

## Cleanup Done ✅

- ✅ Python cache files removed (`__pycache__`, `*.pyc`)
- ✅ `.gitignore` configured for Python/Django
- ✅ Django system check passes
- ✅ No Flutter dependencies
- ✅ Ready for testing!

---

## For Your Presentation

1. **Start server**: `python manage.py runserver`
2. **Open Postman/curl**: Test endpoints live
3. **Show responses**: JSON data with photo metadata
4. **Explain flow**: Registration → Login → Upload → Face clustering

---

## Notes

- **Virtual environment**: Already set up with all dependencies
- **Django 6.0.2**: Latest stable version
- **JWT tokens**: Access (1 day) + Refresh (30 days)
- **AWS integration**: S3 + Rekognition configured
- **No build step**: Just activate venv and run!
