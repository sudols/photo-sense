# Authentication & Database Architecture - Deep Dive

> **For Project Showcase**: Comprehensive guide to PhotoSense's authentication system and database design

---

## 📑 Table of Contents
1. [Authentication Architecture](#authentication-architecture)
2. [JWT Implementation](#jwt-implementation)
3. [Database Design & Schema](#database-design--schema)
4. [Security Measures](#security-measures)
5. [Database Relationships](#database-relationships)
6. [Query Optimization](#query-optimization)
7. [Key Talking Points](#key-talking-points)

---

## 1. Authentication Architecture

### 1.1 Overview

**Authentication Method:** JWT (JSON Web Tokens)  
**Why JWT?** Stateless, scalable, works well with mobile apps

```
┌────────────────┐
│  Flutter App   │
└────────┬───────┘
         │ 1. POST /api/auth/login
         │    {username, password}
         ▼
┌──────────────────────────────┐
│  Django Backend              │
│  ┌────────────────────────┐  │
│  │ Verify credentials     │  │
│  │ Generate JWT token     │  │
│  └────────────────────────┘  │
└────────┬─────────────────────┘
         │ 2. Return tokens
         │    {access, refresh}
         ▼
┌────────────────┐
│  Flutter App   │
│  Stores tokens │
└────────┬───────┘
         │ 3. Subsequent requests
         │    Header: Authorization: Bearer <token>
         ▼
┌──────────────────────────────┐
│  Django Backend              │
│  ┌────────────────────────┐  │
│  │ Validate JWT           │  │
│  │ Extract user           │  │
│  │ Process request        │  │
│  └────────────────────────┘  │
└──────────────────────────────┘
```

---

### 1.2 Authentication Flow - Step by Step

#### Step 1: User Registration
**Endpoint:** `POST /api/auth/register/`

```python
# File: photos/auth_views.py

class RegisterView(View):
    def post(self, request):
        # 1. Parse JSON request
        data = json.loads(request.body)
        email = data.get("email", "").lower().strip()
        password = data.get("password", "")
        
        # 2. Validation
        if not email or not password:
            return {"error": "email and password required"}
        
        # 3. Check if user exists
        if User.objects.filter(username=email).exists():
            return {"error": "email already registered"}
        
        # 4. Create user (password automatically hashed by Django)
        User.objects.create_user(
            username=email,
            email=email,
            password=password  # Django hashes this automatically
        )
        
        return {"message": "account created"}
```

**Key Points:**
- Email used as username (common pattern)
- Django's `create_user()` automatically hashes password using PBKDF2
- Returns 201 status on success

---

#### Step 2: User Login (Get JWT Tokens)
**Endpoint:** `POST /api/auth/login/`

**This endpoint is provided by SimpleJWT library:**

```python
# File: photosense/urls.py
from rest_framework_simplejwt.views import TokenObtainPairView

urlpatterns = [
    path("api/auth/login/", TokenObtainPairView.as_view()),
]
```

**Request:**
```json
POST /api/auth/login/
{
  "username": "user@example.com",
  "password": "password123"
}
```

**Response:**
```json
{
  "access": "eyJ0eXAiOiJKV1QiLCJhbGc...",   // Valid for 1 day
  "refresh": "eyJ0eXAiOiJKV1QiLCJhbG..."   // Valid for 30 days
}
```

**What happens internally:**
1. SimpleJWT verifies username/password against Django User model
2. If valid, generates two tokens:
   - **Access token**: Short-lived (1 day), used for API requests
   - **Refresh token**: Long-lived (30 days), used to get new access tokens

---

#### Step 3: Using Access Token
**Every API request includes the token:**

```http
GET /api/photos/
Authorization: Bearer eyJ0eXAiOiJKV1QiLCJhbGc...
```

**Backend validation (in our AuthenticatedView):**

```python
# File: photos/views.py

class AuthenticatedView(View):
    def dispatch(self, request, *args, **kwargs):
        # 1. Extract token from Authorization header
        jwt_auth = JWTAuthentication()
        
        # 2. Validate token and extract user
        try:
            auth_result = jwt_auth.authenticate(request)
            if auth_result is not None:
                request.user, _ = auth_result  # Attach user to request
            else:
                return JsonResponse({"error": "Authentication required"}, 401)
        except AuthenticationFailed:
            return JsonResponse({"error": "Invalid or expired token"}, 401)
        
        # 3. Continue to actual view method
        return super().dispatch(request, *args, **kwargs)
```

**What JWTAuthentication does:**
1. Parses `Authorization: Bearer <token>` header
2. Verifies JWT signature (prevents tampering)
3. Checks expiration time
4. Extracts user ID from token payload
5. Loads User object from database
6. Returns (user, token) tuple

---

#### Step 4: Refreshing Access Token
**Endpoint:** `POST /api/auth/refresh/`

**When access token expires (after 1 day):**

```json
POST /api/auth/refresh/
{
  "refresh": "eyJ0eXAiOiJKV1QiLCJhbG..."
}
```

**Response:**
```json
{
  "access": "new_access_token_here..."
}
```

**Configuration (settings.py):**
```python
SIMPLE_JWT = {
    "ACCESS_TOKEN_LIFETIME": timedelta(days=1),      # Short-lived
    "REFRESH_TOKEN_LIFETIME": timedelta(days=30),    # Long-lived
}
```

---

### 1.3 Why JWT Instead of Session-Based Auth?

| Aspect | Session-Based | JWT (Our Choice) |
|--------|---------------|------------------|
| **State** | Server stores session | Stateless (no server storage) |
| **Scalability** | Requires sticky sessions | Can scale horizontally easily |
| **Mobile** | Cookies don't work well | Perfect for mobile apps |
| **Cross-domain** | CORS complications | Works everywhere |
| **Storage** | Redis/DB for sessions | No storage needed |

**For PhotoSense:**
- ✅ Mobile app (Flutter) - JWT works better than cookies
- ✅ Small scale - don't need session management overhead
- ✅ Stateless backend - easier to deploy

---

## 2. JWT Implementation Details

### 2.1 JWT Token Structure

A JWT has 3 parts (separated by dots):

```
eyJ0eXAiOiJKV1QiLCJhbGc.eyJ1c2VyX2lkIjoxLCJ.SflKxwRJSMeKKF2QT
    HEADER              PAYLOAD         SIGNATURE
```

**Example decoded:**

**Header:**
```json
{
  "typ": "JWT",
  "alg": "HS256"  // HMAC SHA-256 algorithm
}
```

**Payload:**
```json
{
  "user_id": 1,
  "username": "user@example.com",
  "exp": 1704067200,  // Expiration timestamp
  "iat": 1703980800,  // Issued at timestamp
  "jti": "abc123"     // Unique token ID
}
```

**Signature:**
```
HMACSHA256(
  base64UrlEncode(header) + "." + base64UrlEncode(payload),
  SECRET_KEY
)
```

**Security:** The signature prevents tampering. If someone modifies the payload, the signature won't match (they don't have SECRET_KEY).

---

### 2.2 Password Security

**Password Hashing:**
Django uses PBKDF2 (Password-Based Key Derivation Function 2) by default:

```python
# When user registers:
User.objects.create_user(username=email, password="password123")

# Django stores in database:
password = "pbkdf2_sha256$600000$random_salt$hashed_password"
            └─algorithm  └─iterations └─salt    └─hash
```

**What happens:**
1. Generate random salt
2. Run password through PBKDF2 600,000 times
3. Store: algorithm + iterations + salt + final hash

**Why secure:**
- Salted (prevents rainbow table attacks)
- 600,000 iterations (slow enough to prevent brute force)
- One-way hash (can't reverse to get original password)

**Verification (login):**
```python
# User enters password
entered_password = "password123"

# Django extracts salt and iterations from stored hash
# Runs same PBKDF2 process
# Compares result with stored hash
user.check_password(entered_password)  # True/False
```

---

## 3. Database Design & Schema

### 3.1 Complete Database Schema

```
┌─────────────────────────────┐
│         User                │  (Django built-in)
│─────────────────────────────│
│ PK  id                      │
│     username (email)        │
│     password (hashed)       │
│     email                   │
│     is_active               │
│     date_joined             │
└──────────┬──────────────────┘
           │ 1
           │ owns
           │ *
┌──────────▼──────────────────┐       ┌─────────────────────────┐
│         Photo               │       │        Person           │
│─────────────────────────────│       │─────────────────────────│
│ PK  id (UUID)               │       │ PK  id (UUID)           │
│ FK  owner → User.id         │       │ FK  owner → User.id     │
│     s3_key                  │       │     name                │
│     face_ids (JSON)         │       │     face_id             │
│     detected_text (JSON)    │       │     face_ids (JSON)     │
│     detected_faces (JSON)   │       │     bounding_box (JSON) │
│     faces_count             │       │     thumbnail_s3_key    │
│     analyzed_at             │       │     is_unnamed          │
│     created_at              │       │     created_at          │
│     updated_at              │       │     updated_at          │
└──────────┬──────────────────┘       └──────────┬──────────────┘
           │ *                                   │ *
           │                                     │
           │         ┌───────────────────┐       │
           └────────►│   PhotoPerson     │◄──────┘
                     │   (Join Table)    │
                     │───────────────────│
                     │ PK  id (UUID)     │
                     │ FK  photo_id      │
                     │ FK  person_id     │
                     │ FK  owner_id      │
                     │     created_at    │
                     │                   │
                     │ UNIQUE(photo, person)
                     └───────────────────┘
```

---

### 3.2 Table Details

#### User Table (Django Built-in)
**Purpose:** Store user accounts and authentication data

```sql
CREATE TABLE auth_user (
    id INTEGER PRIMARY KEY,
    username VARCHAR(150) UNIQUE NOT NULL,  -- Uses email
    password VARCHAR(128) NOT NULL,         -- Hashed (PBKDF2)
    email VARCHAR(254),
    is_active BOOLEAN DEFAULT TRUE,
    is_staff BOOLEAN DEFAULT FALSE,
    is_superuser BOOLEAN DEFAULT FALSE,
    date_joined TIMESTAMP DEFAULT NOW()
);

-- Indexes (automatic)
CREATE INDEX ON auth_user(username);
CREATE INDEX ON auth_user(email);
```

**Key Fields:**
- `username`: We use email as username (common pattern)
- `password`: Hashed using PBKDF2 (format: `pbkdf2_sha256$600000$salt$hash`)
- `is_active`: Can disable users without deleting
- `date_joined`: Audit trail

---

#### Photo Table
**Purpose:** Store uploaded photos and ML analysis results

```sql
CREATE TABLE photos_photo (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    owner_id INTEGER REFERENCES auth_user(id) ON DELETE CASCADE,
    s3_key VARCHAR(500) NOT NULL,
    face_ids JSON DEFAULT '[]',              -- AWS face IDs
    detected_text JSON DEFAULT '[]',         -- OCR results
    detected_faces JSON DEFAULT '[]',        -- Face metadata
    faces_count INTEGER DEFAULT 0,
    analyzed_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX ON photos_photo(owner_id);
CREATE INDEX ON photos_photo(created_at DESC);
```

**Key Design Decisions:**

1. **UUID Primary Key**
   - Why? Security (can't guess photo IDs like `/photos/1/`, `/photos/2/`)
   - Format: `550e8400-e29b-41d4-a716-446655440000`

2. **JSONField for ML Results**
   - Why? Flexible storage for AWS Rekognition responses
   - Avoids creating separate tables for complex nested data
   - Example `face_ids`: `["abc-123", "def-456"]`
   - Example `detected_text`: `["Hello World", "Exit Sign"]`

3. **Cascade Delete**
   - `ON DELETE CASCADE`: If user deleted, all their photos deleted too
   - Prevents orphaned records

4. **Timestamps**
   - `created_at`: When photo uploaded
   - `updated_at`: Auto-updates on any change
   - `analyzed_at`: When ML analysis completed

---

#### Person Table
**Purpose:** Represent detected people across photos

```sql
CREATE TABLE photos_person (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    owner_id INTEGER REFERENCES auth_user(id) ON DELETE CASCADE,
    name VARCHAR(255) DEFAULT 'Unknown Person',
    face_id VARCHAR(100),                    -- Primary face
    face_ids JSON DEFAULT '[]',              -- All faces for this person
    bounding_box JSON,                       -- Face coordinates
    thumbnail_s3_key VARCHAR(500),           -- Reference photo
    is_unnamed BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Indexes
CREATE INDEX ON photos_person(owner_id);
CREATE INDEX ON photos_person(is_unnamed);
```

**Key Design Decisions:**

1. **face_ids Array**
   - One person can have multiple face IDs (different angles, lighting)
   - Grows over time as more photos uploaded
   - Example: `["face1", "face2", "face3", "face4"]`

2. **is_unnamed Flag**
   - Quick query: "Show me all unnamed persons" for UI
   - Changes to `False` when user renames

3. **thumbnail_s3_key**
   - Points to first photo where this person appeared
   - Used for UI display

---

#### PhotoPerson Table (Join Table)
**Purpose:** Many-to-many relationship between Photos and Persons

```sql
CREATE TABLE photos_photoperson (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    photo_id UUID REFERENCES photos_photo(id) ON DELETE CASCADE,
    person_id UUID REFERENCES photos_person(id) ON DELETE CASCADE,
    owner_id INTEGER REFERENCES auth_user(id) ON DELETE CASCADE,
    created_at TIMESTAMP DEFAULT NOW(),
    
    CONSTRAINT unique_photo_person UNIQUE(photo_id, person_id)
);

-- Indexes for fast queries
CREATE INDEX ON photos_photoperson(photo_id);
CREATE INDEX ON photos_photoperson(person_id);
CREATE INDEX ON photos_photoperson(owner_id);
```

**Why This Table?**

Without it:
- ❌ Can't have multiple people in one photo
- ❌ Can't show all photos of one person

With it:
- ✅ Query: "Show all photos where John appears"
- ✅ Query: "Show all people in this photo"
- ✅ Supports complex relationships

**Example Data:**
```
photo_id                              | person_id                            | owner_id
----------------------------------------------------------------------
550e8400-e29b-41d4-a716-446655440000 | abc-123 (John Doe)                   | 1
550e8400-e29b-41d4-a716-446655440000 | def-456 (Jane Smith)                 | 1
661f9511-f3ac-52e5-b827-557766551111 | abc-123 (John Doe)                   | 1
```

This shows:
- Photo 1 has John and Jane
- Photo 2 has John only

---

## 4. Security Measures

### 4.1 Authentication Security

```python
# 1. JWT Token Validation
class AuthenticatedView(View):
    def dispatch(self, request, *args, **kwargs):
        jwt_auth = JWTAuthentication()
        try:
            auth_result = jwt_auth.authenticate(request)
            if auth_result is not None:
                request.user, _ = auth_result
            else:
                return JsonResponse({"error": "Authentication required"}, 401)
        except AuthenticationFailed:
            return JsonResponse({"error": "Invalid or expired token"}, 401)
        
        return super().dispatch(request, *args, **kwargs)
```

**Security Features:**
- ✅ Validates JWT signature (prevents tampering)
- ✅ Checks expiration time
- ✅ Returns 401 for invalid/expired tokens

---

### 4.2 Data Isolation (Multi-Tenancy)

**Every query filters by owner:**

```python
# User can ONLY see their own photos
photos = Photo.objects.filter(owner=request.user)

# User can ONLY see their own persons
persons = Person.objects.filter(owner=request.user)

# User can ONLY delete their own photos
photo = Photo.objects.get(id=pk, owner=request.user)
```

**What this prevents:**
- ❌ User A cannot see User B's photos
- ❌ User A cannot delete User B's data
- ❌ User A cannot access User B's person clusters

**Database-level security:**
```sql
-- Every table has owner_id
-- Every query includes WHERE owner_id = current_user
SELECT * FROM photos_photo WHERE owner_id = 1;
SELECT * FROM photos_person WHERE owner_id = 1;
```

---

### 4.3 Password Security

**Django's Built-in Validators (settings.py):**

```python
AUTH_PASSWORD_VALIDATORS = [
    {
        "NAME": "django.contrib.auth.password_validation.UserAttributeSimilarityValidator"
        # Prevents password similar to username/email
    },
    {
        "NAME": "django.contrib.auth.password_validation.MinimumLengthValidator"
        # Default: 8 characters minimum
    },
    {
        "NAME": "django.contrib.auth.password_validation.CommonPasswordValidator"
        # Rejects common passwords (password123, qwerty, etc.)
    },
    {
        "NAME": "django.contrib.auth.password_validation.NumericPasswordValidator"
        # Prevents all-numeric passwords
    },
]
```

**Hashing Algorithm:**
```
PBKDF2 SHA-256 with 600,000 iterations
Format: pbkdf2_sha256$600000$<random_salt>$<hash>
```

---

### 4.4 CSRF Protection

**CSRF Disabled for API Endpoints:**

```python
@method_decorator(csrf_exempt, name='dispatch')
class AuthenticatedView(View):
    # CSRF exempt because we use JWT tokens
    pass
```

**Why disabled:**
- JWT tokens provide CSRF protection
- Mobile apps don't use cookies (CSRF is cookie-based attack)
- Each request has explicit Authorization header

---

### 4.5 CORS Configuration

**Settings (settings.py):**

```python
CORS_ALLOW_ALL_ORIGINS = DEBUG  # Only in development

# Production would use:
CORS_ALLOWED_ORIGINS = [
    "https://photosense-app.com",
    "https://mobile.photosense-app.com"
]
```

**Why needed:**
- Browsers block cross-origin requests by default
- Flutter web app might run on different domain
- Mobile apps don't enforce CORS (browser-only mechanism)

---

## 5. Database Relationships

### 5.1 One-to-Many Relationships

**User → Photos (One user has many photos)**

```python
# From User perspective
user = User.objects.get(id=1)
user_photos = user.photos.all()  # All photos for this user

# From Photo perspective
photo = Photo.objects.get(id="uuid-here")
owner = photo.owner  # The user who owns this photo
```

**SQL equivalent:**
```sql
-- Get user's photos
SELECT * FROM photos_photo WHERE owner_id = 1;

-- Get photo's owner
SELECT * FROM auth_user 
WHERE id = (SELECT owner_id FROM photos_photo WHERE id = 'uuid');
```

---

**User → Persons (One user has many persons)**

```python
# Get all persons detected for a user
user_persons = Person.objects.filter(owner=user)

# Get unnamed persons only
unnamed = Person.objects.filter(owner=user, is_unnamed=True)
```

---

### 5.2 Many-to-Many Relationship

**Photos ↔ Persons (via PhotoPerson)**

```python
# Get all persons in a photo
photo = Photo.objects.get(id="photo-uuid")
persons_in_photo = Person.objects.filter(photo_persons__photo=photo)

# Get all photos containing a person
person = Person.objects.get(id="person-uuid")
photos_with_person = Photo.objects.filter(photo_persons__person=person)

# Create link
PhotoPerson.objects.create(
    photo=photo,
    person=person,
    owner=user
)
```

**SQL equivalent:**
```sql
-- Persons in a photo
SELECT p.* 
FROM photos_person p
JOIN photos_photoperson pp ON p.id = pp.person_id
WHERE pp.photo_id = 'photo-uuid';

-- Photos containing a person
SELECT ph.*
FROM photos_photo ph
JOIN photos_photoperson pp ON ph.id = pp.photo_id
WHERE pp.person_id = 'person-uuid';
```

---

## 6. Query Optimization

### 6.1 Database Indexes

**Automatic indexes (Django creates these):**
```sql
-- Primary keys (automatic)
CREATE INDEX ON photos_photo(id);
CREATE INDEX ON photos_person(id);

-- Foreign keys (automatic)
CREATE INDEX ON photos_photo(owner_id);
CREATE INDEX ON photos_person(owner_id);
CREATE INDEX ON photos_photoperson(photo_id);
CREATE INDEX ON photos_photoperson(person_id);
```

**Why indexes matter:**
```sql
-- Without index: Full table scan (slow)
SELECT * FROM photos_photo WHERE owner_id = 1;  -- O(n)

-- With index: Binary search (fast)
SELECT * FROM photos_photo WHERE owner_id = 1;  -- O(log n)
```

---

### 6.2 N+1 Query Problem

**Bad (N+1 queries):**
```python
# Gets all persons (1 query)
persons = Person.objects.filter(owner=user)

# For each person, get photos (N queries)
for person in persons:
    photos = Photo.objects.filter(photo_persons__person=person)  # N queries!
    print(photos)

# Total: 1 + N queries (if 100 persons = 101 queries!)
```

**Good (2 queries with prefetch):**
```python
# Get persons with related photos in 2 queries
persons = Person.objects.filter(owner=user).prefetch_related(
    'photo_persons__photo'
)

# Now accessing photos doesn't hit database
for person in persons:
    photos = person.photo_persons.all()  # No extra query!
    
# Total: 2 queries regardless of person count
```

**Our implementation (views.py):**
```python
def person_to_dict(person, include_photos=False):
    data = {...}
    
    if include_photos:
        # Explicit query - clear and understandable
        photos = Photo.objects.filter(photo_persons__person=person)
        data["photos"] = [photo_to_dict(p) for p in photos]
    
    return data
```

**Note:** For semester project scale (2-3 users), N+1 is acceptable. Production would use `prefetch_related()`.

---

### 6.3 Query Examples

**Get all photos for a user (ordered by newest):**
```python
photos = Photo.objects.filter(owner=request.user).order_by('-created_at')
```

**Search photos by text:**
```python
photos = Photo.objects.filter(
    owner=request.user,
    detected_text__icontains=query  # Case-insensitive search in JSON
)
```

**Find person by face ID:**
```python
person = Person.objects.filter(
    owner=user,
    face_ids__contains=face_id  # Search in JSON array
).first()
```

**Get photos with specific person:**
```python
photos = Photo.objects.filter(
    owner=user,
    photo_persons__person=person
).distinct()  # Avoid duplicates
```

---

## 7. Key Talking Points for Presentation

### 7.1 Authentication Highlights

**"We use JWT for stateless authentication"**
- ✅ Perfect for mobile apps (no cookies needed)
- ✅ Scalable (no server-side session storage)
- ✅ Secure (signed tokens prevent tampering)
- ✅ Access tokens expire after 1 day
- ✅ Refresh tokens last 30 days

**"Passwords are hashed using PBKDF2 with 600,000 iterations"**
- ✅ Industry-standard algorithm
- ✅ Salted to prevent rainbow table attacks
- ✅ Slow enough to prevent brute force

---

### 7.2 Database Design Highlights

**"We use UUIDs for primary keys"**
- ✅ Security: Can't guess IDs (`/photos/550e8400...` vs `/photos/1/`)
- ✅ Distributed systems friendly (no ID collision)
- ✅ Good practice for public-facing APIs

**"Three-table design with join table for many-to-many"**
- ✅ User → Photos (one-to-many)
- ✅ User → Persons (one-to-many)
- ✅ Photos ↔ Persons (many-to-many via PhotoPerson)

**"JSONField for ML results"**
- ✅ Flexible storage for AWS Rekognition responses
- ✅ Avoids complex normalized schema
- ✅ PostgreSQL has excellent JSON support

---

### 7.3 Security Highlights

**"Every query is scoped to the authenticated user"**
```python
Photo.objects.filter(owner=request.user)  # Always!
```
- ✅ Users can't see others' data
- ✅ Database-level isolation
- ✅ Prevents unauthorized access

**"Cascade deletes prevent orphaned records"**
- ✅ Delete user → all their photos/persons deleted
- ✅ Delete photo → all PhotoPerson links deleted
- ✅ Database consistency maintained

---

## 8. Database Migration Example

**Django automatically creates migration files:**

```python
# Initial migration (auto-generated)
class Migration(migrations.Migration):
    operations = [
        migrations.CreateModel(
            name='Photo',
            fields=[
                ('id', models.UUIDField(default=uuid.uuid4, primary_key=True)),
                ('s3_key', models.CharField(max_length=500)),
                ('face_ids', models.JSONField(default=list)),
                ('detected_text', models.JSONField(default=list)),
                ('faces_count', models.IntegerField(default=0)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('owner', models.ForeignKey(
                    on_delete=models.CASCADE,
                    to='auth.User',
                    related_name='photos'
                )),
            ],
        ),
    ]
```

**Run migrations:**
```bash
python manage.py makemigrations  # Generate migration files
python manage.py migrate         # Apply to database
```

---

## 9. Quick Reference

### Authentication Flow
```
1. Register → Create user with hashed password
2. Login → Get JWT access + refresh tokens
3. API calls → Send access token in Authorization header
4. Backend → Validate token, extract user, process request
5. Token expired → Use refresh token to get new access token
```

### Database Queries
```python
# User's photos
Photo.objects.filter(owner=user)

# Photos with person
Photo.objects.filter(photo_persons__person=person)

# Unnamed persons
Person.objects.filter(owner=user, is_unnamed=True)

# Search photos
Photo.objects.filter(detected_text__icontains=query)
```

### Security Checklist
- ✅ JWT tokens signed and verified
- ✅ Passwords hashed with PBKDF2
- ✅ All queries scoped to authenticated user
- ✅ UUIDs prevent ID guessing
- ✅ Cascade deletes prevent orphans
- ✅ CORS configured for production

---

## 10. Common Interview Questions

**Q: Why JWT instead of sessions?**  
A: JWT is stateless (no server storage), works better with mobile apps, and scales horizontally easily. Sessions require Redis/database for storage and sticky sessions for load balancing.

**Q: How do you prevent SQL injection?**  
A: Django's ORM automatically parameterizes queries. We never concatenate user input into SQL strings.

**Q: Why UUIDs instead of auto-increment IDs?**  
A: Security - can't guess photo IDs. Also good for distributed systems and prevents enumeration attacks.

**Q: How do you handle database migrations?**  
A: Django's migration system tracks schema changes. `makemigrations` generates migration files, `migrate` applies them. All changes are version-controlled.

**Q: What about database backups?**  
A: Production uses managed PostgreSQL on Render with automatic daily backups. Development uses SQLite (file-based, easy to copy).

**Q: How would you scale the database?**  
A: Add read replicas for queries, connection pooling (pgBouncer), caching (Redis), database indexes on frequently queried fields, pagination for large datasets.

---

## Summary

**Authentication:**
- JWT-based, stateless, mobile-friendly
- PBKDF2 password hashing with 600k iterations
- Access tokens (1 day) + Refresh tokens (30 days)

**Database:**
- 4 tables: User, Photo, Person, PhotoPerson
- UUIDs for security
- JSONField for flexible ML data storage
- Proper foreign keys with cascade deletes
- Data isolation per user

**Security:**
- All queries scoped to authenticated user
- Token validation on every request
- Password validators prevent weak passwords
- CORS configured appropriately

---

**You're ready to discuss auth and database design in depth!** 🚀
