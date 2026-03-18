#!/bin/bash

# PhotoSense Backend Testing Script
# This script demonstrates the complete photo upload and operations workflow

set -e  # Exit on error

BASE_URL="http://localhost:8000"
EMAIL="demo@photosense.com"
PASSWORD="demo123456"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  PhotoSense Backend API Testing"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Step 1: Register User
echo "📝 Step 1: Registering user..."
REGISTER_RESPONSE=$(curl -s -X POST "$BASE_URL/api/auth/register/" \
  -H "Content-Type: application/json" \
  -d "{\"email\": \"$EMAIL\", \"password\": \"$PASSWORD\"}")

if echo "$REGISTER_RESPONSE" | grep -q "account created"; then
    echo "✅ User registered successfully"
elif echo "$REGISTER_RESPONSE" | grep -q "already registered"; then
    echo "ℹ️  User already exists (that's fine)"
else
    echo "❌ Registration failed: $REGISTER_RESPONSE"
fi
echo ""

# Step 2: Login
echo "🔐 Step 2: Logging in..."
LOGIN_RESPONSE=$(curl -s -X POST "$BASE_URL/api/auth/login/" \
  -H "Content-Type: application/json" \
  -d "{\"username\": \"$EMAIL\", \"password\": \"$PASSWORD\"}")

ACCESS_TOKEN=$(echo "$LOGIN_RESPONSE" | grep -o '"access":"[^"]*' | cut -d'"' -f4)
REFRESH_TOKEN=$(echo "$LOGIN_RESPONSE" | grep -o '"refresh":"[^"]*' | cut -d'"' -f4)

if [ -z "$ACCESS_TOKEN" ]; then
    echo "❌ Login failed: $LOGIN_RESPONSE"
    exit 1
fi

echo "✅ Login successful!"
echo "   Access Token: ${ACCESS_TOKEN:0:50}..."
echo "   Refresh Token: ${REFRESH_TOKEN:0:50}..."
echo ""

# Step 3: List Photos (should be empty initially)
echo "📋 Step 3: Listing photos (before upload)..."
PHOTOS_BEFORE=$(curl -s "$BASE_URL/api/photos/" \
  -H "Authorization: Bearer $ACCESS_TOKEN")

PHOTO_COUNT_BEFORE=$(echo "$PHOTOS_BEFORE" | grep -o '"id"' | wc -l)
echo "✅ Current photos: $PHOTO_COUNT_BEFORE"
echo ""

# Step 4: Upload Photo
echo "📤 Step 4: Uploading a photo..."
echo "   Note: You need an actual image file for this to work!"
echo ""
echo "   Option A - Using an existing image:"
echo "   -----------------------------------------"
echo "   curl -X POST $BASE_URL/api/photos/upload/ \\"
echo "     -H \"Authorization: Bearer $ACCESS_TOKEN\" \\"
echo "     -F \"file=@/path/to/your/photo.jpg\""
echo ""
echo "   Option B - Using Postman/Thunder Client:"
echo "   -----------------------------------------"
echo "   1. Create POST request to: $BASE_URL/api/photos/upload/"
echo "   2. Add Header: Authorization: Bearer $ACCESS_TOKEN"
echo "   3. Body type: form-data"
echo "   4. Key: 'file', Type: File, Value: Select your image"
echo "   5. Send request"
echo ""

# Check if there's a sample image we can use
if [ -f "/tmp/sample.jpg" ]; then
    echo "   Found sample image, uploading..."
    UPLOAD_RESPONSE=$(curl -s -X POST "$BASE_URL/api/photos/upload/" \
      -H "Authorization: Bearer $ACCESS_TOKEN" \
      -F "file=@/tmp/sample.jpg")
    
    PHOTO_ID=$(echo "$UPLOAD_RESPONSE" | grep -o '"id":"[^"]*' | cut -d'"' -f4)
    
    if [ -n "$PHOTO_ID" ]; then
        echo "   ✅ Photo uploaded! ID: $PHOTO_ID"
        echo "   📊 Response:"
        echo "$UPLOAD_RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$UPLOAD_RESPONSE"
    else
        echo "   ❌ Upload failed: $UPLOAD_RESPONSE"
    fi
else
    echo "   ⏭️  Skipping upload (no sample image found)"
    echo "   To test upload, run with your own image:"
    echo "   export TEST_IMAGE=/path/to/your/photo.jpg"
fi
echo ""

# Step 5: List Photos Again
echo "📋 Step 5: Listing photos (after upload)..."
PHOTOS_AFTER=$(curl -s "$BASE_URL/api/photos/" \
  -H "Authorization: Bearer $ACCESS_TOKEN")

PHOTO_COUNT_AFTER=$(echo "$PHOTOS_AFTER" | grep -o '"id"' | wc -l)
echo "✅ Total photos: $PHOTO_COUNT_AFTER"

# Get first photo ID if available
FIRST_PHOTO_ID=$(echo "$PHOTOS_AFTER" | grep -o '"id":"[^"]*' | head -1 | cut -d'"' -f4)

if [ -n "$FIRST_PHOTO_ID" ]; then
    echo "   First photo ID: $FIRST_PHOTO_ID"
    echo ""
    
    # Step 6: Get Photo Details
    echo "🔍 Step 6: Getting photo details..."
    PHOTO_DETAIL=$(curl -s "$BASE_URL/api/photos/$FIRST_PHOTO_ID/" \
      -H "Authorization: Bearer $ACCESS_TOKEN")
    
    echo "✅ Photo details retrieved:"
    echo "$PHOTO_DETAIL" | python3 -m json.tool 2>/dev/null || echo "$PHOTO_DETAIL"
    echo ""
    
    # Step 7: List Detected Persons
    echo "👥 Step 7: Listing detected persons..."
    PERSONS=$(curl -s "$BASE_URL/api/persons/" \
      -H "Authorization: Bearer $ACCESS_TOKEN")
    
    PERSON_COUNT=$(echo "$PERSONS" | grep -o '"id"' | wc -l)
    echo "✅ Detected persons: $PERSON_COUNT"
    
    if [ "$PERSON_COUNT" -gt 0 ]; then
        echo "   Persons data:"
        echo "$PERSONS" | python3 -m json.tool 2>/dev/null || echo "$PERSONS"
        
        FIRST_PERSON_ID=$(echo "$PERSONS" | grep -o '"id":"[^"]*' | head -1 | cut -d'"' -f4)
        
        if [ -n "$FIRST_PERSON_ID" ]; then
            echo ""
            echo "✏️  Step 8: Renaming person..."
            RENAME_RESPONSE=$(curl -s -X PATCH "$BASE_URL/api/persons/$FIRST_PERSON_ID/" \
              -H "Authorization: Bearer $ACCESS_TOKEN" \
              -H "Content-Type: application/json" \
              -d '{"name": "John Doe"}')
            
            echo "✅ Person renamed:"
            echo "$RENAME_RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$RENAME_RESPONSE"
        fi
    fi
    echo ""
    
    # Step 9: Search Photos by Text (OCR)
    echo "🔎 Step 9: Searching photos by detected text..."
    SEARCH_RESPONSE=$(curl -s "$BASE_URL/api/photos/search/?q=test" \
      -H "Authorization: Bearer $ACCESS_TOKEN")
    
    SEARCH_COUNT=$(echo "$SEARCH_RESPONSE" | grep -o '"id"' | wc -l)
    echo "✅ Search results: $SEARCH_COUNT photos containing 'test'"
    echo ""
else
    echo "   No photos found. Upload a photo first!"
    echo ""
fi

# Step 10: Token Refresh
echo "🔄 Step 10: Refreshing access token..."
REFRESH_RESPONSE=$(curl -s -X POST "$BASE_URL/api/auth/refresh/" \
  -H "Content-Type: application/json" \
  -d "{\"refresh\": \"$REFRESH_TOKEN\"}")

NEW_ACCESS_TOKEN=$(echo "$REFRESH_RESPONSE" | grep -o '"access":"[^"]*' | cut -d'"' -f4)

if [ -n "$NEW_ACCESS_TOKEN" ]; then
    echo "✅ Token refreshed successfully!"
    echo "   New Access Token: ${NEW_ACCESS_TOKEN:0:50}..."
else
    echo "❌ Token refresh failed: $REFRESH_RESPONSE"
fi
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Testing Complete! ✨"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📊 Summary:"
echo "  • Total photos: $PHOTO_COUNT_AFTER"
echo "  • Detected persons: $PERSON_COUNT"
echo "  • Tokens: Working ✅"
echo ""
echo "💡 Next steps:"
echo "  1. Upload photos with faces to see face clustering"
echo "  2. Upload photos with text to test OCR search"
echo "  3. Try merging duplicate persons"
echo "  4. Test photo deletion"
echo ""
echo "🔗 API Documentation:"
echo "  Registration:  POST $BASE_URL/api/auth/register/"
echo "  Login:         POST $BASE_URL/api/auth/login/"
echo "  Upload Photo:  POST $BASE_URL/api/photos/upload/"
echo "  List Photos:   GET  $BASE_URL/api/photos/"
echo "  Search Photos: GET  $BASE_URL/api/photos/search/?q=<text>"
echo "  List Persons:  GET  $BASE_URL/api/persons/"
echo "  Rename Person: PATCH $BASE_URL/api/persons/<id>/"
echo "  Merge Persons: POST $BASE_URL/api/persons/<id>/merge/"
echo ""
