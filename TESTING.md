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

## Complete API Testing with curl

### Step 1: Authentication

**Register a new user:**
```bash
curl -X POST http://localhost:8000/api/auth/register/ \
  -H "Content-Type: application/json" \
  -d '{"email": "test@example.com", "password": "testpass123"}'
```

**Expected response:**
```json
{"message": "account created"}
```

**Login (get JWT tokens):**
```bash
curl -X POST http://localhost:8000/api/auth/login/ \
  -H "Content-Type: application/json" \
  -d '{"username": "test@example.com", "password": "testpass123"}'
```

**Expected response:**
```json
{
  "access": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refresh": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**💡 Save your access token:**
```bash
export TOKEN="YOUR_ACCESS_TOKEN_HERE"
```

**Refresh access token:**
```bash
curl -X POST http://localhost:8000/api/auth/refresh/ \
  -H "Content-Type: application/json" \
  -d '{"refresh": "YOUR_REFRESH_TOKEN_HERE"}'
```

---

### Step 2: Photo Operations

**Upload a photo (with face detection & OCR):**
```bash
curl -X POST http://localhost:8000/api/photos/upload/ \
  -H "Authorization: Bearer $TOKEN" \
  -F "file=@/path/to/your/photo.jpg"
```

**Expected response:**
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "owner": 1,
  "s3_key": "photos/user_1/550e8400.jpg",
  "face_ids": ["face-123", "face-456"],
  "detected_text": ["Hello World", "Welcome"],
  "detected_faces": [
    {
      "faceId": "face-123",
      "boundingBox": {"Left": 0.3, "Top": 0.2, "Width": 0.15, "Height": 0.2},
      "confidence": 99.8
    }
  ],
  "faces_count": 2,
  "url": "https://s3.amazonaws.com/...",
  "analyzed_at": "2026-03-18T13:00:00Z",
  "created_at": "2026-03-18T13:00:00Z",
  "updated_at": "2026-03-18T13:00:00Z"
}
```

**List all photos:**
```bash
curl http://localhost:8000/api/photos/ \
  -H "Authorization: Bearer $TOKEN"
```

**Get photo details:**
```bash
curl http://localhost:8000/api/photos/550e8400-e29b-41d4-a716-446655440000/ \
  -H "Authorization: Bearer $TOKEN"
```

**Search photos by detected text (OCR):**
```bash
curl "http://localhost:8000/api/photos/search/?q=hello" \
  -H "Authorization: Bearer $TOKEN"
```

**Delete a photo:**
```bash
curl -X DELETE http://localhost:8000/api/photos/550e8400-e29b-41d4-a716-446655440000/ \
  -H "Authorization: Bearer $TOKEN"
```

---

### Step 3: Person Operations

**List all detected persons:**
```bash
curl http://localhost:8000/api/persons/ \
  -H "Authorization: Bearer $TOKEN"
```

**Expected response:**
```json
[
  {
    "id": "a1b2c3d4-...",
    "name": "Unknown Person",
    "face_id": "face-123",
    "face_ids": ["face-123", "face-456"],
    "is_unnamed": true,
    "photo_count": 3,
    "created_at": "2026-03-18T13:00:00Z"
  }
]
```

**Get person details:**
```bash
curl http://localhost:8000/api/persons/a1b2c3d4-e5f6-7890-abcd-ef1234567890/ \
  -H "Authorization: Bearer $TOKEN"
```

**Rename a person:**
```bash
curl -X PATCH http://localhost:8000/api/persons/a1b2c3d4-e5f6-7890-abcd-ef1234567890/ \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name": "John Doe"}'
```

**Merge duplicate persons:**
```bash
curl -X POST http://localhost:8000/api/persons/PERSON_ID_TO_KEEP/merge/ \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"source_person_id": "PERSON_ID_TO_MERGE"}'
```

**Delete a person:**
```bash
curl -X DELETE http://localhost:8000/api/persons/a1b2c3d4-e5f6-7890-abcd-ef1234567890/ \
  -H "Authorization: Bearer $TOKEN"
```

---

## Complete Testing Workflow

Here's a complete example flow from start to finish:

```bash
# 1. Register
curl -X POST http://localhost:8000/api/auth/register/ \
  -H "Content-Type: application/json" \
  -d '{"email": "demo@photosense.com", "password": "demo123456"}'

# 2. Login and save token
TOKEN=$(curl -s -X POST http://localhost:8000/api/auth/login/ \
  -H "Content-Type: application/json" \
  -d '{"username": "demo@photosense.com", "password": "demo123456"}' \
  | grep -o '"access":"[^"]*' | cut -d'"' -f4)

echo "Token: $TOKEN"

# 3. Upload a photo
curl -X POST http://localhost:8000/api/photos/upload/ \
  -H "Authorization: Bearer $TOKEN" \
  -F "file=@/path/to/photo.jpg"

# 4. List photos
curl http://localhost:8000/api/photos/ \
  -H "Authorization: Bearer $TOKEN"

# 5. List detected persons
curl http://localhost:8000/api/persons/ \
  -H "Authorization: Bearer $TOKEN"

# 6. Search by text
curl "http://localhost:8000/api/photos/search/?q=hello" \
  -H "Authorization: Bearer $TOKEN"
```

---

## Photo Upload - What Happens Behind the Scenes

When you upload a photo, the backend performs **7 steps**:

1. **File Validation** - Checks file type and size
2. **S3 Upload** - Stores image in AWS S3 bucket
3. **Face Detection** - AWS Rekognition detects and indexes faces
4. **Text Detection** - AWS Rekognition performs OCR to extract text
5. **Database Save** - Creates Photo record with ML results
6. **Face Clustering** - Matches faces to existing persons (90% threshold)
7. **Response** - Returns photo JSON with presigned URL

**Processing time:** 3-7 seconds (AWS API calls)

---

## Testing Tips

### Save Token for Multiple Requests
```bash
# Login and extract token
export TOKEN=$(curl -s -X POST http://localhost:8000/api/auth/login/ \
  -H "Content-Type: application/json" \
  -d '{"username": "test@example.com", "password": "testpass123"}' \
  | grep -o '"access":"[^"]*' | cut -d'"' -f4)

# Now use $TOKEN in all requests
curl http://localhost:8000/api/photos/ \
  -H "Authorization: Bearer $TOKEN"
```

### Pretty Print JSON Responses
```bash
curl http://localhost:8000/api/photos/ \
  -H "Authorization: Bearer $TOKEN" \
  | python3 -m json.tool
```

### Upload Multiple Photos
```bash
for photo in /path/to/photos/*.jpg; do
  echo "Uploading $photo..."
  curl -X POST http://localhost:8000/api/photos/upload/ \
    -H "Authorization: Bearer $TOKEN" \
    -F "file=@$photo"
  sleep 2  # Wait between uploads
done
```

---

## Environment Variables

Check `backend/.env` for AWS credentials:
```bash
cat backend/.env
```

Required variables:
- `AWS_ACCESS_KEY_ID` - AWS access key
- `AWS_SECRET_ACCESS_KEY` - AWS secret key
- `AWS_STORAGE_BUCKET_NAME` - S3 bucket name
- `AWS_REKOGNITION_COLLECTION_ID` - Rekognition collection ID
- `AWS_REGION` - AWS region (e.g., us-east-1)

---

## Database

**Default**: SQLite (`backend/db.sqlite3`)

**Run migrations:**
```bash
python manage.py migrate
```

**Create superuser for admin panel:**
```bash
python manage.py createsuperuser
```

**Access admin panel:** http://localhost:8000/admin/

**View database directly:**
```bash
sqlite3 backend/db.sqlite3
.tables
SELECT * FROM photos_photo;
.quit
```

---

## Troubleshooting

**"Invalid token" error**
- Token expired (1-day lifetime). Login again to get new token.

**"File required" error**
- Make sure you're using `-F "file=@/path/to/image.jpg"` with curl

**"AWS error" messages**
- Check `backend/.env` has correct AWS credentials
- Verify S3 bucket exists and is accessible
- Verify Rekognition collection exists

**Upload takes 3-7 seconds**
- Normal! AWS Rekognition face detection and OCR take time

**403 Forbidden**
- Token missing or invalid. Include `Authorization: Bearer $TOKEN` header

---

## For Your Presentation

**Demo Script:**
1. Start server: `python manage.py runserver`
2. Register user (show curl command)
3. Login (show JWT token response)
4. Upload photo with faces (show 7-step process)
5. List photos (show JSON with face_ids, detected_text)
6. List persons (show face clustering worked)
7. Rename person (show PATCH request)
8. Search by text (show OCR search works)

**Talking Points:**
- "Upload triggers 7-step pipeline with AWS integration"
- "Face clustering uses 90% similarity threshold"
- "JWT tokens: 1-day access, 30-day refresh (stateless auth)"
- "All data isolated by user - can't see other users' photos"
- "UUIDs as primary keys for security"

---

## Quick Test Script

Run the automated test script:
```bash
./test_api.sh
```

This will test all endpoints and show you the complete flow!
