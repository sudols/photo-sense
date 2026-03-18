# Authentication & Database - Visual Diagrams

## Authentication Flow - Complete Visualization

```
═══════════════════════════════════════════════════════════════════
                    1. USER REGISTRATION
═══════════════════════════════════════════════════════════════════

┌─────────────┐
│ Flutter App │
└──────┬──────┘
       │ POST /api/auth/register/
       │ {
       │   "email": "user@example.com",
       │   "password": "MySecurePass123"
       │ }
       ▼
┌─────────────────────────────────────────────────────┐
│ Django Backend - RegisterView                       │
│                                                      │
│ 1. Validate input                                   │
│    if not email or not password:                    │
│        return 400                                   │
│                                                      │
│ 2. Check if user exists                             │
│    if User.objects.filter(username=email).exists(): │
│        return 400 "already registered"              │
│                                                      │
│ 3. Create user with hashed password                 │
│    User.objects.create_user(                        │
│        username=email,                              │
│        password=password  ← Django hashes this      │
│    )                                                 │
└──────────────────────┬──────────────────────────────┘
                       │
                       ▼
              ┌────────────────────┐
              │ PostgreSQL Database│
              │                    │
              │ auth_user table:   │
              │ ├─ id: 1           │
              │ ├─ username: user@ │
              │ ├─ password:       │
              │ │  pbkdf2_sha256$  │
              │ │  600000$salt$... │
              │ └─ date_joined     │
              └────────────────────┘
                       │
                       │ Success
                       ▼
                ┌─────────────┐
                │ Flutter App │
                │ Shows:      │
                │ "Account    │
                │  created!"  │
                └─────────────┘


═══════════════════════════════════════════════════════════════════
                        2. LOGIN (GET JWT)
═══════════════════════════════════════════════════════════════════

┌─────────────┐
│ Flutter App │
└──────┬──────┘
       │ POST /api/auth/login/
       │ {
       │   "username": "user@example.com",
       │   "password": "MySecurePass123"
       │ }
       ▼
┌──────────────────────────────────────────────────┐
│ SimpleJWT Library (TokenObtainPairView)          │
│                                                   │
│ 1. Look up user                                  │
│    user = User.objects.get(username=email)       │
│                                                   │
│ 2. Verify password                               │
│    if not user.check_password(password):         │
│        return 401 "Invalid credentials"          │
│                                                   │
│ 3. Generate JWT tokens                           │
│    access_token = create_access_token(user)      │
│    refresh_token = create_refresh_token(user)    │
└──────────────────┬───────────────────────────────┘
                   │
                   ▼
        ┌─────────────────────────┐
        │ Token Generation        │
        │                         │
        │ ACCESS TOKEN:           │
        │ ┌─────────────────────┐ │
        │ │ Header:             │ │
        │ │ {type: JWT, alg:... }│ │
        │ │                     │ │
        │ │ Payload:            │ │
        │ │ {                   │ │
        │ │   user_id: 1,       │ │
        │ │   exp: <1 day>      │ │
        │ │ }                   │ │
        │ │                     │ │
        │ │ Signature:          │ │
        │ │ HMAC(header+payload,│ │
        │ │      SECRET_KEY)    │ │
        │ └─────────────────────┘ │
        │                         │
        │ REFRESH TOKEN:          │
        │ (same structure,        │
        │  30-day expiry)         │
        └────────┬────────────────┘
                 │
                 │ JSON Response
                 ▼
          ┌────────────────────┐
          │ {                  │
          │   "access": "eyJ...",  │
          │   "refresh": "eyJ..." │
          │ }                  │
          └──────┬─────────────┘
                 │
                 ▼
          ┌─────────────┐
          │ Flutter App │
          │ Stores:     │
          │ • access    │
          │ • refresh   │
          │ in secure   │
          │ storage     │
          └─────────────┘


═══════════════════════════════════════════════════════════════════
               3. AUTHENTICATED API REQUEST
═══════════════════════════════════════════════════════════════════

┌─────────────┐
│ Flutter App │
│ Has tokens  │
│ stored      │
└──────┬──────┘
       │ GET /api/photos/
       │ Headers:
       │   Authorization: Bearer eyJ0eXAiOiJKV1QiLCJhbGc...
       │
       ▼
┌──────────────────────────────────────────────────┐
│ Django - AuthenticatedView.dispatch()            │
│                                                   │
│ Step 1: Extract token from header                │
│ ─────────────────────────────────                │
│   auth_header = request.META['HTTP_AUTHORIZATION']│
│   # "Bearer eyJ0eXAi..."                         │
│                                                   │
│   token = auth_header.split()[1]                 │
│   # "eyJ0eXAi..."                                │
└──────────────────┬───────────────────────────────┘
                   │
                   ▼
┌──────────────────────────────────────────────────┐
│ Step 2: Validate JWT Token                       │
│ ──────────────────────────                       │
│                                                   │
│ jwt_auth = JWTAuthentication()                   │
│                                                   │
│ a) Decode token (base64)                         │
│    header = decode(token.part1)                  │
│    payload = decode(token.part2)                 │
│    signature = token.part3                       │
│                                                   │
│ b) Verify signature                              │
│    expected = HMAC(header + payload, SECRET_KEY) │
│    if signature != expected:                     │
│        raise AuthenticationFailed ✗              │
│                                                   │
│ c) Check expiration                              │
│    if payload['exp'] < now():                    │
│        raise AuthenticationFailed ✗              │
│                                                   │
│ d) Extract user_id                               │
│    user_id = payload['user_id']  # e.g., 1       │
└──────────────────┬───────────────────────────────┘
                   │ ✓ Valid
                   ▼
┌──────────────────────────────────────────────────┐
│ Step 3: Load User from Database                  │
│ ───────────────────────────────                  │
│                                                   │
│   user = User.objects.get(id=user_id)            │
│                                                   │
│   ┌─────────────────────┐                        │
│   │ Database Query:     │                        │
│   │ SELECT *            │                        │
│   │ FROM auth_user      │                        │
│   │ WHERE id = 1        │                        │
│   └─────────────────────┘                        │
│                                                   │
│   request.user = user  ← Attach to request       │
└──────────────────┬───────────────────────────────┘
                   │
                   ▼
┌──────────────────────────────────────────────────┐
│ Step 4: Process Request                          │
│ ──────────────────────                           │
│                                                   │
│ def get(self, request):                          │
│     # User already attached to request!          │
│     photos = Photo.objects.filter(               │
│         owner=request.user  ← Uses authenticated │
│     )                          user              │
│     return [photo_to_dict(p) for p in photos]    │
└──────────────────┬───────────────────────────────┘
                   │
                   │ JSON Response
                   ▼
            ┌─────────────┐
            │ Flutter App │
            │ Displays    │
            │ photos      │
            └─────────────┘


═══════════════════════════════════════════════════════════════════
              4. TOKEN REFRESH (When Access Expires)
═══════════════════════════════════════════════════════════════════

After 1 day, access token expires...

┌─────────────┐
│ Flutter App │
│ Access token│
│ expired ✗   │
└──────┬──────┘
       │ POST /api/auth/refresh/
       │ {
       │   "refresh": "eyJ0eXAiOiJKV1QiLCJhbGc..."
       │ }
       ▼
┌──────────────────────────────────────────────────┐
│ SimpleJWT - TokenRefreshView                     │
│                                                   │
│ 1. Validate refresh token                        │
│    - Check signature                             │
│    - Check expiration (30 days)                  │
│    - Extract user_id                             │
│                                                   │
│ 2. Generate NEW access token                     │
│    access_token = create_access_token(user_id)   │
│    # New 1-day expiry                            │
└──────────────────┬───────────────────────────────┘
                   │
                   ▼
            ┌─────────────┐
            │ {           │
            │   "access": │
            │   "new_..."  │
            │ }           │
            └──────┬──────┘
                   │
                   ▼
            ┌─────────────┐
            │ Flutter App │
            │ Updates     │
            │ stored      │
            │ access token│
            └─────────────┘


═══════════════════════════════════════════════════════════════════
                      PASSWORD HASHING
═══════════════════════════════════════════════════════════════════

User enters password: "MySecurePass123"
                          │
                          ▼
┌─────────────────────────────────────────────────────┐
│ Django: User.objects.create_user(password=...)      │
│                                                      │
│ Step 1: Generate random salt                        │
│ salt = random_bytes(16)                              │
│ # e.g., "2a4f8b3c9e7d"                              │
│                                                      │
│ Step 2: Hash with PBKDF2                            │
│ for i in range(600000):  # 600k iterations          │
│     hash = HMAC_SHA256(password + salt)             │
│     password = hash  # Use output as next input     │
│                                                      │
│ Step 3: Store in format                             │
│ stored = f"pbkdf2_sha256${iterations}${salt}${hash}"│
└──────────────────────┬──────────────────────────────┘
                       │
                       ▼
              ┌─────────────────────────────────┐
              │ Database Stored Password:       │
              │                                 │
              │ pbkdf2_sha256$600000$2a4f8b..$ │
              │ 9f8a7c5d3e1b2f...              │
              │ └─algorithm  └─iterations       │
              │              └─salt             │
              │              └─hash (64 chars)  │
              └─────────────────────────────────┘

Login verification:
1. User enters password
2. Extract salt from stored hash
3. Run same PBKDF2 process (600k iterations)
4. Compare result with stored hash
5. Match? ✓ Login success | No match? ✗ Invalid password


═══════════════════════════════════════════════════════════════════
                   DATABASE SCHEMA RELATIONSHIPS
═══════════════════════════════════════════════════════════════════

        ┌─────────────────────────────────────┐
        │           auth_user                 │
        │─────────────────────────────────────│
        │ PK  id (int)                        │
        │     username (email)                │
        │     password (hashed)               │
        │     email                           │
        │     is_active                       │
        │     date_joined                     │
        └───────────┬─────────────────────────┘
                    │
                    │ One user owns many photos
                    │ (One-to-Many via owner_id)
                    │
        ┌───────────┴─────────────┬───────────────────────┐
        │                         │                       │
        ▼                         ▼                       ▼
┌───────────────────┐   ┌───────────────────┐   ┌───────────────────┐
│  photos_photo     │   │  photos_person    │   │ photos_photoperson│
│───────────────────│   │───────────────────│   │───────────────────│
│ PK id (UUID)      │   │ PK id (UUID)      │   │ PK id (UUID)      │
│ FK owner_id ──────┼───│ FK owner_id ──────┼───│ FK owner_id       │
│    s3_key         │   │    name           │   │ FK photo_id ──┐   │
│    face_ids[]     │   │    face_id        │   │ FK person_id ─┼─┐ │
│    detected_text[]│   │    face_ids[]     │   │    created_at │ │ │
│    faces_count    │   │    thumbnail_s3_key│   │               │ │ │
│    created_at     │   │    is_unnamed     │   │ UNIQUE(photo, │ │ │
│    updated_at     │   │    created_at     │   │        person)│ │ │
└─────────┬─────────┘   └─────────┬─────────┘   └───────────────┘ │ │
          │                       │                     ▲           │ │
          │                       │                     │           │ │
          │ Many-to-Many via PhotoPerson                │           │ │
          └───────────────────────┴─────────────────────┘───────────┘ │
                                                        │               │
                                                        └───────────────┘

Example Data Flow:

User uploads photo with 2 faces (John and Jane):

1. Insert into photos_photo:
   ┌──────────────────────────────────────┐
   │ id: uuid-001                         │
   │ owner_id: 1                          │
   │ face_ids: ["face-abc", "face-def"]   │
   └──────────────────────────────────────┘

2. Face clustering creates persons:
   ┌─────────────────────────────┐   ┌─────────────────────────────┐
   │ Person 1 (John)             │   │ Person 2 (Jane)             │
   │ id: uuid-101                │   │ id: uuid-102                │
   │ owner_id: 1                 │   │ owner_id: 1                 │
   │ name: "Unknown Person"      │   │ name: "Unknown Person"      │
   │ face_ids: ["face-abc"]      │   │ face_ids: ["face-def"]      │
   └─────────────────────────────┘   └─────────────────────────────┘

3. Create PhotoPerson links:
   ┌──────────────────────────────┐   ┌──────────────────────────────┐
   │ photo_id: uuid-001           │   │ photo_id: uuid-001           │
   │ person_id: uuid-101 (John)   │   │ person_id: uuid-102 (Jane)   │
   │ owner_id: 1                  │   │ owner_id: 1                  │
   └──────────────────────────────┘   └──────────────────────────────┘


═══════════════════════════════════════════════════════════════════
                      QUERY EXAMPLES
═══════════════════════════════════════════════════════════════════

1. Get all photos for logged-in user:
   ────────────────────────────────
   
   Python:
   Photo.objects.filter(owner=request.user)
   
   SQL:
   SELECT * FROM photos_photo WHERE owner_id = 1;


2. Get all persons in a specific photo:
   ────────────────────────────────────
   
   Python:
   Person.objects.filter(photo_persons__photo=photo)
   
   SQL:
   SELECT p.*
   FROM photos_person p
   JOIN photos_photoperson pp ON p.id = pp.person_id
   WHERE pp.photo_id = 'uuid-001';


3. Get all photos containing a specific person:
   ─────────────────────────────────────────────
   
   Python:
   Photo.objects.filter(photo_persons__person=person)
   
   SQL:
   SELECT ph.*
   FROM photos_photo ph
   JOIN photos_photoperson pp ON ph.id = pp.photo_id
   WHERE pp.person_id = 'uuid-101';


4. Search photos by detected text:
   ────────────────────────────────
   
   Python:
   Photo.objects.filter(
       owner=request.user,
       detected_text__icontains='hello'
   )
   
   SQL (PostgreSQL JSON):
   SELECT * FROM photos_photo
   WHERE owner_id = 1
   AND detected_text::text ILIKE '%hello%';


5. Get unnamed persons:
   ────────────────────
   
   Python:
   Person.objects.filter(owner=user, is_unnamed=True)
   
   SQL:
   SELECT * FROM photos_person
   WHERE owner_id = 1 AND is_unnamed = TRUE;


═══════════════════════════════════════════════════════════════════
                    SECURITY LAYERS
═══════════════════════════════════════════════════════════════════

Layer 1: JWT Token Validation
┌────────────────────────────────────┐
│ Every request must have valid JWT  │
│ • Signature verified               │
│ • Expiration checked               │
│ • User extracted                   │
└────────────────────────────────────┘
               │
               ▼
Layer 2: User Isolation (Multi-tenancy)
┌────────────────────────────────────┐
│ Every query filters by owner:      │
│ Photo.objects.filter(owner=user)   │
│                                     │
│ User A cannot access User B's data │
└────────────────────────────────────┘
               │
               ▼
Layer 3: Database Constraints
┌────────────────────────────────────┐
│ • Foreign keys enforce referential │
│   integrity                        │
│ • UNIQUE constraints prevent       │
│   duplicates                       │
│ • CASCADE deletes remove orphans   │
└────────────────────────────────────┘
               │
               ▼
Layer 4: Password Security
┌────────────────────────────────────┐
│ • PBKDF2 with 600k iterations      │
│ • Random salt per password         │
│ • One-way hash (irreversible)      │
└────────────────────────────────────┘


═══════════════════════════════════════════════════════════════════
              CASCADE DELETE BEHAVIOR
═══════════════════════════════════════════════════════════════════

User deleted → What happens?

┌─────────────┐
│ DELETE      │
│ User (id=1) │
└──────┬──────┘
       │
       │ CASCADE DELETE
       │
       ├─────────────────────────────────────┐
       │                                     │
       ▼                                     ▼
┌───────────────┐                   ┌────────────────┐
│ All Photos    │                   │ All Persons    │
│ owned by      │                   │ owned by       │
│ User 1        │                   │ User 1         │
│ DELETED ✗     │                   │ DELETED ✗      │
└───────┬───────┘                   └────────┬───────┘
        │                                    │
        │ CASCADE DELETE                     │
        │                                    │
        ▼                                    ▼
┌─────────────────────────────────────────────────┐
│ All PhotoPerson links                           │
│ for those photos/persons                        │
│ DELETED ✗                                       │
└─────────────────────────────────────────────────┘

Result: Complete cleanup, no orphaned records!


═══════════════════════════════════════════════════════════════════
                    INDEXES FOR PERFORMANCE
═══════════════════════════════════════════════════════════════════

Without Index:
┌────────────────────────────────────┐
│ SELECT * FROM photos_photo         │
│ WHERE owner_id = 1;                │
│                                     │
│ ┌───┬─────────┬────────┐           │
│ │ 1 │ owner_1 │ ... ✓  │ ← Check   │
│ │ 2 │ owner_2 │ ... ✗  │ ← Check   │
│ │ 3 │ owner_1 │ ... ✓  │ ← Check   │
│ │ 4 │ owner_3 │ ... ✗  │ ← Check   │
│ │...│   ...   │ ...    │ ← Check   │
│ └───┴─────────┴────────┘           │
│                                     │
│ Full table scan: O(n)               │
│ 1000 rows = 1000 checks             │
└────────────────────────────────────┘

With Index on owner_id:
┌────────────────────────────────────┐
│ Index (B-Tree):                    │
│                                     │
│         [owner_2]                  │
│         /        \                 │
│   [owner_1]   [owner_3]            │
│      ↓                              │
│   Rows: 1, 3, 7, 9, ...            │
│                                     │
│ Binary search: O(log n)             │
│ 1000 rows = ~10 checks              │
└────────────────────────────────────┘

Automatic indexes:
✓ Primary keys (id)
✓ Foreign keys (owner_id, photo_id, person_id)
✓ Unique constraints


═══════════════════════════════════════════════════════════════════
                    COMPLETE REQUEST FLOW
═══════════════════════════════════════════════════════════════════

GET /api/photos/ with JWT token

1. HTTP Request
   Authorization: Bearer eyJ0eXAi...
          │
          ▼
2. Django Middleware
   • CORS check
   • Security headers
          │
          ▼
3. URL Routing
   /api/photos/ → PhotoListView
          │
          ▼
4. AuthenticatedView.dispatch()
   • Extract JWT token
   • Validate signature
   • Check expiration
   • Load user from DB
   • Attach to request.user
          │
          ▼
5. PhotoListView.get()
   • Query: Photo.objects.filter(owner=request.user)
   • Database executes: SELECT * FROM photos_photo WHERE owner_id = 1
   • Returns list of Photo objects
          │
          ▼
6. Response Serialization
   • photo_to_dict() for each photo
   • Generate presigned S3 URLs
   • Convert to JSON
          │
          ▼
7. HTTP Response
   {
     "photos": [
       {"id": "...", "url": "https://s3...", ...},
       ...
     ]
   }


═══════════════════════════════════════════════════════════════════

This comprehensive visualization shows every aspect of authentication
and database design in PhotoSense!
