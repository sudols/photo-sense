# 📸 Photo Upload & Operations - Step by Step Guide

## Prerequisites
✅ Django server is running at `http://localhost:8000`
✅ You have JWT access token (from login)

---

## Method 1: Using curl (Command Line)

### Step 1: Get Your Access Token
```bash
# Login first
curl -X POST http://localhost:8000/api/auth/login/ \
  -H "Content-Type: application/json" \
  -d '{"username": "demo@photosense.com", "password": "demo123456"}'

# Copy the "access" token from response
```

### Step 2: Upload a Photo
```bash
# Replace YOUR_ACCESS_TOKEN and /path/to/photo.jpg
curl -X POST http://localhost:8000/api/photos/upload/ \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -F "file=@/path/to/photo.jpg"
```

**What happens during upload (7 steps):**
1. ✅ File validation
2. ✅ S3 upload (cloud storage)
3. ✅ AWS Rekognition face detection
4. ✅ AWS Rekognition text detection (OCR)
5. ✅ Database save (Photo record)
6. ✅ Face clustering (matches faces to persons)
7. ✅ Returns photo JSON with presigned URL

### Step 3: View Uploaded Photos
```bash
curl http://localhost:8000/api/photos/ \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

### Step 4: View Detected Persons
```bash
curl http://localhost:8000/api/persons/ \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

### Step 5: Search Photos by Text (OCR)
```bash
curl "http://localhost:8000/api/photos/search/?q=hello" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

---

## Method 2: Using Postman (Recommended for Testing)

### Setup Postman Collection

1. **Create New Collection** → "PhotoSense API"

2. **Add Environment Variables:**
   - `base_url`: `http://localhost:8000`
   - `access_token`: (will be set after login)

### Request 1: Register
- **Method:** POST
- **URL:** `{{base_url}}/api/auth/register/`
- **Headers:** `Content-Type: application/json`
- **Body (raw JSON):**
  ```json
  {
    "email": "test@example.com",
    "password": "testpass123"
  }
  ```

### Request 2: Login
- **Method:** POST
- **URL:** `{{base_url}}/api/auth/login/`
- **Headers:** `Content-Type: application/json`
- **Body (raw JSON):**
  ```json
  {
    "username": "test@example.com",
    "password": "testpass123"
  }
  ```
- **Test Script** (to auto-save token):
  ```javascript
  pm.environment.set("access_token", pm.response.json().access);
  ```

### Request 3: Upload Photo ⭐
- **Method:** POST
- **URL:** `{{base_url}}/api/photos/upload/`
- **Headers:** `Authorization: Bearer {{access_token}}`
- **Body:** 
  - Select `form-data`
  - Key: `file` (change type to "File")
  - Value: Click "Select Files" and choose an image
- **Click Send**

### Request 4: List Photos
- **Method:** GET
- **URL:** `{{base_url}}/api/photos/`
- **Headers:** `Authorization: Bearer {{access_token}}`

### Request 5: Get Photo Details
- **Method:** GET
- **URL:** `{{base_url}}/api/photos/{photo_id}/`
- **Headers:** `Authorization: Bearer {{access_token}}`
- Replace `{photo_id}` with actual UUID from previous request

### Request 6: List Detected Persons
- **Method:** GET
- **URL:** `{{base_url}}/api/persons/`
- **Headers:** `Authorization: Bearer {{access_token}}`

### Request 7: Rename Person
- **Method:** PATCH
- **URL:** `{{base_url}}/api/persons/{person_id}/`
- **Headers:** 
  - `Authorization: Bearer {{access_token}}`
  - `Content-Type: application/json`
- **Body (raw JSON):**
  ```json
  {
    "name": "John Doe"
  }
  ```

### Request 8: Search Photos by Text
- **Method:** GET
- **URL:** `{{base_url}}/api/photos/search/?q=hello`
- **Headers:** `Authorization: Bearer {{access_token}}`

### Request 9: Delete Photo
- **Method:** DELETE
- **URL:** `{{base_url}}/api/photos/{photo_id}/`
- **Headers:** `Authorization: Bearer {{access_token}}`

---

## Method 3: Using VS Code Thunder Client Extension

1. **Install Thunder Client** extension in VS Code
2. **Import Collection** (same structure as Postman above)
3. **Test upload** with GUI interface

---

## What to Upload for Best Results

### For Face Detection Testing:
- ✅ Upload photos with clear faces (frontal view)
- ✅ Upload multiple photos of same person → see face clustering work
- ✅ Upload group photos → see multiple persons detected

### For OCR Testing:
- ✅ Upload photos with text (signs, documents, screenshots)
- ✅ Then search using `/api/photos/search/?q=<text>`

### For Testing Without AWS:
**Note:** Your current setup requires AWS credentials in `.env`:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_STORAGE_BUCKET_NAME`
- `AWS_REKOGNITION_COLLECTION_ID`

If AWS is not configured, upload will fail. Check `backend/.env` file.

---

## Expected Response from Upload

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "owner": 1,
  "s3_key": "photos/user_1/550e8400-e29b-41d4-a716-446655440000.jpg",
  "face_ids": ["face-id-123", "face-id-456"],
  "detected_text": ["Hello World", "Welcome"],
  "detected_faces": [
    {
      "faceId": "face-id-123",
      "boundingBox": {
        "Left": 0.3,
        "Top": 0.2,
        "Width": 0.15,
        "Height": 0.2
      },
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

---

## Troubleshooting

### "Invalid token" error
→ Token expired (1 day lifetime). Login again to get new token.

### "File required" error
→ Make sure you're sending as `multipart/form-data` with key `file`

### "AWS error" messages
→ Check `backend/.env` has correct AWS credentials

### Upload takes 3-7 seconds
→ Normal! AWS Rekognition processing takes time

---

## Quick Test Script

Run this for quick testing:
```bash
./test_api.sh
```

This will:
1. Register user
2. Login
3. Get JWT tokens
4. List photos
5. Show upload instructions
6. Test token refresh

---

## For Your Presentation

**Demo Flow:**
1. Show Postman collection
2. Login → Get JWT token
3. Upload photo with faces
4. Show response JSON (face_ids, detected_text)
5. List persons → Show face clustering worked
6. Rename a person
7. Search photos by text

**Talking Points:**
- "Upload triggers 7-step pipeline"
- "Face clustering uses 90% similarity threshold"
- "JWT tokens expire after 1 day (configurable)"
- "All data isolated by user (can't see other users' photos)"
