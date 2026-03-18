# Authentication & Database - Presentation Cheat Sheet

> **Quick Reference**: Key points for showcasing authentication and database design

---

## 🎯 30-Second Summary

**Authentication:**
"We use JWT tokens for stateless authentication - perfect for mobile apps. Passwords are hashed with PBKDF2 using 600,000 iterations. Access tokens last 1 day, refresh tokens last 30 days."

**Database:**
"Four-table design: User, Photo, Person, and PhotoPerson join table. We use UUIDs for security, JSONField for flexible ML data storage, and proper foreign key relationships with cascade deletes. Every query is scoped to the authenticated user for data isolation."

---

## 🔐 Authentication Highlights

### JWT Token System

**Access Token (1 day):**
```json
{
  "user_id": 1,
  "exp": 1704067200,
  "iat": 1703980800
}
```
- Used for API requests
- Sent in `Authorization: Bearer <token>` header
- Stateless (no server storage)

**Refresh Token (30 days):**
- Used to get new access token when expired
- Stored securely by mobile app

### Password Security

**Storage Format:**
```
pbkdf2_sha256$600000$<random_salt>$<hash>
```

**Key Features:**
- ✅ PBKDF2 algorithm (industry standard)
- ✅ 600,000 iterations (prevents brute force)
- ✅ Random salt per password (prevents rainbow tables)
- ✅ One-way hash (can't reverse)

### Authentication Flow

```
1. Login → Verify credentials → Generate JWT tokens
2. API request → Validate token → Extract user → Process request
3. Token expired → Use refresh token → Get new access token
```

---

## 🗄️ Database Design Highlights

### Schema Overview

**4 Tables:**
1. **User** (Django built-in) - Authentication data
2. **Photo** - Uploaded images + ML results
3. **Person** - Detected people clusters
4. **PhotoPerson** - Join table (many-to-many)

### Key Design Decisions

**1. UUID Primary Keys**
```python
id = models.UUIDField(primary_key=True, default=uuid.uuid4)
```
**Why?**
- ✅ Security: Can't guess IDs (`/photos/550e8400...` vs `/photos/1/`)
- ✅ Distributed systems friendly
- ✅ Industry best practice for APIs

**2. JSONField for ML Data**
```python
face_ids = models.JSONField(default=list)  # ["face1", "face2"]
detected_text = models.JSONField(default=list)  # ["Hello", "World"]
```
**Why?**
- ✅ Flexible storage for AWS Rekognition responses
- ✅ No need for complex normalized schema
- ✅ PostgreSQL has excellent JSON support

**3. Foreign Key Relationships**
```python
owner = models.ForeignKey(User, on_delete=models.CASCADE)
```
**Why CASCADE?**
- ✅ Delete user → all their data deleted automatically
- ✅ Prevents orphaned records
- ✅ Database consistency maintained

### Relationships

```
User 1──────→ * Photo    (One user, many photos)
User 1──────→ * Person   (One user, many persons)
Photo *─────→ * Person   (Many-to-many via PhotoPerson)
```

**PhotoPerson Join Table:**
- Links photos to persons
- Enables queries like "show all photos of John"
- Supports multiple people per photo

---

## 🔒 Security Features

### 1. Data Isolation (Multi-Tenancy)

**Every query filters by owner:**
```python
# Users can ONLY see their own data
Photo.objects.filter(owner=request.user)
Person.objects.filter(owner=request.user)
```

**What this prevents:**
- ❌ User A accessing User B's photos
- ❌ User A deleting User B's data
- ❌ Cross-user data leakage

### 2. JWT Validation

**On every request:**
```python
1. Extract token from Authorization header
2. Verify signature (prevents tampering)
3. Check expiration
4. Load user from database
5. Attach to request.user
```

### 3. Password Validation

**Django built-in validators:**
- MinimumLengthValidator (8 chars)
- CommonPasswordValidator (rejects "password123")
- NumericPasswordValidator (no all-numbers)
- UserAttributeSimilarityValidator (not similar to email)

### 4. Database Constraints

```sql
-- Prevent duplicate photo-person links
UNIQUE(photo_id, person_id)

-- Enforce data integrity
FOREIGN KEY (owner_id) REFERENCES auth_user(id)

-- Auto-cleanup on delete
ON DELETE CASCADE
```

---

## 📊 Database Queries Explained

### Common Queries

**1. Get user's photos:**
```python
Photo.objects.filter(owner=request.user).order_by('-created_at')
```
```sql
SELECT * FROM photos_photo 
WHERE owner_id = 1 
ORDER BY created_at DESC;
```

**2. Get persons in a photo:**
```python
Person.objects.filter(photo_persons__photo=photo)
```
```sql
SELECT p.* FROM photos_person p
JOIN photos_photoperson pp ON p.id = pp.person_id
WHERE pp.photo_id = 'uuid-here';
```

**3. Search photos by text:**
```python
Photo.objects.filter(detected_text__icontains='hello')
```
```sql
SELECT * FROM photos_photo 
WHERE detected_text::text ILIKE '%hello%';
```

**4. Get unnamed persons:**
```python
Person.objects.filter(owner=user, is_unnamed=True)
```
```sql
SELECT * FROM photos_person 
WHERE owner_id = 1 AND is_unnamed = TRUE;
```

---

## 🎬 Demo Flow for Presentation

### Part 1: Authentication (2-3 minutes)

**Show:**
1. `auth_views.py` - Registration endpoint
2. `settings.py` - JWT configuration
3. `views.py` - AuthenticatedView class

**Talk about:**
- "Users register with email and password"
- "Passwords are hashed with PBKDF2 - 600,000 iterations"
- "Login returns two JWT tokens: access (1 day) and refresh (30 days)"
- "Every API request validates the JWT token before processing"

**Draw on whiteboard:**
```
Login → JWT Tokens → API Request → Validate Token → Process
```

### Part 2: Database Design (3-4 minutes)

**Show:**
1. `models.py` - All three model classes
2. Point out key fields
3. Show relationships

**Talk about:**
- "Four tables: User, Photo, Person, PhotoPerson"
- "Photo stores the uploaded image location and ML results"
- "Person represents a detected individual across multiple photos"
- "PhotoPerson is the join table - one photo can have many people"
- "We use UUIDs for security and JSONField for flexible ML data"

**Draw on whiteboard:**
```
User ──→ Photos
  └────→ Persons
        ↕
     Photos ←→ Persons (via PhotoPerson)
```

### Part 3: Security (1-2 minutes)

**Show:**
1. `views.py` - User isolation in queries

**Talk about:**
- "Every query filters by the authenticated user"
- "User A cannot see User B's data at all"
- "Database enforces referential integrity with foreign keys"
- "Cascade deletes prevent orphaned records"

---

## ❓ Common Questions & Answers

### Authentication

**Q: Why JWT instead of sessions?**  
A: JWT is stateless (no server storage required), works better with mobile apps, and scales horizontally easily. Sessions would require Redis or database storage and sticky sessions for load balancing.

**Q: What if someone steals the JWT token?**  
A: Tokens expire after 1 day. For production, we'd use HTTPS only, shorter expiry times, and token rotation. We could also implement token blacklisting if needed.

**Q: How do you validate the password?**  
A: Django's `check_password()` extracts the salt and iterations from the stored hash, runs the same PBKDF2 process on the entered password, and compares the results. If they match, password is correct.

### Database

**Q: Why not use auto-increment IDs?**  
A: UUIDs prevent enumeration attacks. With sequential IDs, users could guess other photo IDs (`/photos/1/`, `/photos/2/`). UUIDs make this impossible.

**Q: Why store ML results in the database instead of re-computing?**  
A: AWS Rekognition costs money per API call. Storing results means we only analyze each photo once. It's also much faster - instant display instead of 3-7 second wait.

**Q: What happens if two users upload the same photo?**  
A: They're stored separately with different UUIDs and different S3 keys. Each user's data is completely isolated. Face detection runs independently for each upload.

**Q: How do you handle database migrations?**  
A: Django's migration system tracks all schema changes. When we modify models, `makemigrations` generates a migration file, and `migrate` applies it to the database. All changes are version-controlled.

**Q: What about database backups?**  
A: Production uses managed PostgreSQL on Render with automatic daily backups and point-in-time recovery. Development uses SQLite which is file-based and easy to backup.

### Security

**Q: Can users see each other's photos?**  
A: No. Every query includes `owner=request.user` filter. The database only returns data belonging to the authenticated user.

**Q: What if the JWT secret key is compromised?**  
A: All tokens would be invalid. We'd rotate the secret key (environment variable), invalidating all existing tokens. Users would need to log in again.

**Q: How do you prevent SQL injection?**  
A: Django's ORM automatically parameterizes queries. We never concatenate user input into SQL strings. All queries use placeholders that are safely escaped.

---

## 📝 Code Snippets to Show

### 1. Registration (auth_views.py)
```python
def post(self, request):
    email = data.get("email", "").lower().strip()
    password = data.get("password", "")
    
    if User.objects.filter(username=email).exists():
        return JsonResponse({"error": "email already registered"}, 400)
    
    User.objects.create_user(username=email, password=password)
    return JsonResponse({"message": "account created"}, 201)
```

**Key point:** "create_user() automatically hashes the password"

### 2. JWT Configuration (settings.py)
```python
SIMPLE_JWT = {
    "ACCESS_TOKEN_LIFETIME": timedelta(days=1),
    "REFRESH_TOKEN_LIFETIME": timedelta(days=30),
}
```

**Key point:** "Short-lived access token, long-lived refresh token"

### 3. User Isolation (views.py)
```python
def get(self, request):
    photos = Photo.objects.filter(owner=request.user)
    return self.json_response([photo_to_dict(p) for p in photos])
```

**Key point:** "Always filter by owner - users can only see their own data"

### 4. Photo Model (models.py)
```python
class Photo(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4)
    owner = models.ForeignKey(User, on_delete=models.CASCADE)
    face_ids = models.JSONField(default=list)
    detected_text = models.JSONField(default=list)
```

**Key point:** "UUID for security, JSONField for flexible ML data"

---

## 🎨 Whiteboard Diagrams to Draw

### Authentication Flow
```
┌─────────┐    Login     ┌─────────┐
│  User   │─────────────→│ Backend │
└─────────┘              └────┬────┘
                              │ Verify password
                              │ Generate JWT
     ┌────────────────────────┘
     ▼
┌─────────┐   Access Token
│  User   │   (1 day)
└─────────┘
```

### Database Relationships
```
     User
      │
   ┌──┴──┐
   ▼     ▼
Photo  Person
   ╲   ╱
    ╲ ╱
PhotoPerson
```

### Data Isolation
```
User A's View:
├── Photo 1
├── Photo 2
└── Person 1

User B's View:
├── Photo 3
├── Photo 4
└── Person 2

❌ User A CANNOT see Photo 3 or Person 2
```

---

## 🚀 Key Takeaways

### Authentication
- ✅ JWT tokens (stateless, mobile-friendly)
- ✅ PBKDF2 password hashing (600k iterations)
- ✅ Access (1 day) + Refresh (30 days) tokens
- ✅ Token validation on every request

### Database
- ✅ 4 tables with proper relationships
- ✅ UUIDs for security
- ✅ JSONField for ML flexibility
- ✅ Cascade deletes for cleanup

### Security
- ✅ User data isolation
- ✅ JWT signature verification
- ✅ Password validators
- ✅ Foreign key constraints

---

## 📊 Quick Stats

```
Authentication Method:     JWT (JSON Web Tokens)
Password Algorithm:        PBKDF2 SHA-256
Password Iterations:       600,000
Access Token Lifetime:     1 day
Refresh Token Lifetime:    30 days
Database Tables:           4
Primary Key Type:          UUID
Data Storage Format:       JSON for ML results
User Data Isolation:       100% (owner-filtered queries)
```

---

## 🎯 Closing Statement

"Our authentication system uses industry-standard JWT tokens with PBKDF2 password hashing. The database design follows best practices with proper relationships, UUIDs for security, and complete user data isolation. Every query is scoped to the authenticated user, ensuring no cross-user data leakage."

---

**You're ready to present authentication and database design with confidence!** 🚀
