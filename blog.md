# Architecting an AI-Powered Photo Gallery with Face Clustering and OCR

So I built a photo gallery app.

I'd been wanting to sharpen my Flutter skills with a real project — something beyond the usual todo lists and weather apps. The criteria were loose but specific enough: it had to be a domain that maps naturally to Flutter's Material UI, something visual and interactive, and ideally something that touched the AI space, which felt too interesting to ignore entirely.

A photo gallery checked all three boxes. Flutter's grid layouts, bottom navigation, and image widgets are practically made for it. Material 3 gives you search bars, chips, and cards that look genuinely polished without much effort. And the AI angle — automatic face clustering and in-image text recognition — turned what would've been a generic CRUD app into something worth actually building.

The core idea: what if your gallery could automatically figure out _who_ is in every photo, and let you search by text it can _see_ inside the image? Not metadata you typed in yourself, not filenames — the actual visual content. You upload a birthday party photo and the app just groups it with other photos of the same people. There's a cake with "Happy Birthday Rohan" written on it. You type "Rohan" into search. It finds the photo. That's the whole pitch.

Let me walk through how it actually got built — including the part where I rewrote the entire backend halfway through.

---

## The Initial Stack: Amplify

I needed a backend fast. Not "fast" in performance terms — fast as in I didn't want to spend three weeks wiring up auth, file storage, and a database before I could even touch the interesting part, which was the AI. AWS Amplify Gen 2 was genuinely the right call here.

One afternoon. That's all it took to get Cognito handling sign-up and sign-in, an S3 bucket for photo storage, AppSync giving me a GraphQL API, DynamoDB as the database, and a Lambda function that fired automatically on every S3 upload. The whole backend, wired up, deployed to `ap-south-1`, in one afternoon.

That Lambda function is where the real work happened. The moment a photo landed in S3, it called Amazon Rekognition — two API calls. `IndexFaces` to detect and index any faces, and `DetectText` to pull out readable text (the OCR part). Results came back as JSON. Stored in DynamoDB. Done.

And it worked. Weirdly well, for something thrown together that fast.

The Flutter frontend was calling Amplify's SDK for everything: `Amplify.Auth.signIn()`, `Amplify.Storage.uploadFile()`, `Amplify.API.query()` for GraphQL. The code was, uh, _verbose_ — uploading a single photo meant a three-step dance: get a presigned URL from S3, PUT the file to that URL, then fire a GraphQL mutation to create the Photo record in DynamoDB. Loading thumbnails meant calling `Amplify.Storage.getUrl()` per photo, individually, one by one. A textbook N+1 network call problem that I just sort of… accepted and moved on from.

---

## Face Clustering — the Actually Hard Part

Face _detection_ is easy. Rekognition's `IndexFaces` tells you how many faces are in an image, returns bounding box coordinates for each, and assigns every face a unique `FaceId`. Simple.

What it doesn't do is connect the dots across photos. It won't say "this face in Tuesday's photo is the same person as the face from last week." That part — grouping all photos of the same individual into a single _Person_ entity without the user manually tagging anyone — is the face _clustering_ problem, and that's what I had to solve.

Here's the approach. Every face detected gets stored in a Rekognition _collection_, which is basically Rekognition's own managed face database — it indexes the face vector for similarity matching. Then, for each newly detected face, I call `SearchFaces`, which searches the entire collection and returns the closest matching face along with a similarity score. The threshold I picked is 90%. Above that, same person. Below it, or no match at all, new person.

Each `Person` record keeps a JSON list of all the `FaceId`s that belong to it, accumulated across every photo they've appeared in. When a familiar face comes in with a new photo, the algorithm finds the right `Person`, appends the new `FaceId`, then creates a `PhotoPerson` link — one row in a junction table tying that photo to that person.

```python
def _cluster_face(face, photo, user):
    face_id = face['face_id']
    matched_id = search_faces(face_id)   # returns best match or None
    person = None

    if matched_id:
        person = Person.objects.filter(
            owner=user,
            face_ids__contains=matched_id,
        ).first()
        if person and face_id not in person.face_ids:
            person.face_ids.append(face_id)
            person.save()

    if not person:
        person = Person.objects.create(
            owner=user,
            name='Unknown Person',
            face_id=face_id,
            face_ids=[face_id],
            bounding_box=face['bounding_box'],
            thumbnail_s3_key=photo.s3_key,
            is_unnamed=True,
        )

    PhotoPerson.objects.get_or_create(photo=photo, person=person, defaults={'owner': user})
```

It's not fancy. It doesn't need to be. At the scale this app runs — a handful of users, a few hundred photos — this is completely fine.

The 90% threshold is a deliberate choice. A higher threshold means you occasionally get _false negatives_: the same person gets split into two separate `Person` records because Rekognition wasn't confident enough. A lower threshold risks _false positives_: two different people get merged into one. False negatives are recoverable. False positives are messy. So the app leans toward splitting, and gives users a manual merge button to fix it when needed.

That merge endpoint — `POST /api/persons/{id}/merge/` — combines two `Person` records: merges their `face_ids` lists, re-links all the `PhotoPerson` rows from the source to the target, and deletes the source. One API call. If Rekognition decided your brother and cousin are two separate people, you tap Merge and they're one.

---

## OCR — Simpler Than Expected

Honestly, this part surprised me with how little code it took.

Rekognition's `DetectText` gives back every bit of text it can find in an image, tagged as either `WORD` or `LINE`, each with a confidence score. I filter to `LINE` entries above 80% confidence and store them as a plain JSON array on the Photo record. That's the whole pipeline.

A whiteboard photo becomes `["Team Sprint Review", "Q1 Goals", "Action Items"]`. A shop front might give `["Sharma General Store", "Since 1987"]`. A birthday photo: `["Happy Birthday Rohan"]`.

Search, then, is just this:

```python
photos = self.get_queryset().filter(detected_text__icontains=query)
```

One line. Case-insensitive substring match against the stored text array, server-side, scoped to the logged-in user's photos. The old Amplify version fetched _all_ photos to the device and filtered them in Flutter — which obviously falls apart the moment someone has more than a few dozen photos. This version doesn't.

---

## The Backend Rewrite

Here's where the project took a sharp turn.

Partway through, the backend needed to move from Amplify to Django. Partly a course requirement — Django is in the curriculum. Partly because explaining AppSync GraphQL mutation syntax and DynamoDB scan operations to someone unfamiliar with AWS is just genuinely difficult, and a Django REST API with an ORM and an admin panel is a much more accessible thing to demonstrate and discuss.

So: new branch, `django-backend`, start fresh.

S3 and Rekognition stayed. There was no reason to touch them — the boto3 calls worked, the Rekognition collection already had indexed faces in it, the S3 bucket was fine. Everything in between changed: AppSync → Django REST Framework, DynamoDB → PostgreSQL (SQLite locally, zero config), Lambda → synchronous Django view code, Cognito → `djangorestframework-simplejwt`.

| Layer        | Technology                                      |
| ------------ | ----------------------------------------------- |
| Frontend     | Flutter 3.x, Material 3                         |
| Backend      | Django 4.2 + Django REST Framework              |
| Auth         | SimpleJWT (1-day access tokens, 30-day refresh) |
| Database     | PostgreSQL (prod) / SQLite (dev)                |
| File Storage | Amazon S3 (same bucket, kept)                   |
| ML / AI      | Amazon Rekognition via boto3 (kept)             |
| Deployment   | Render.com                                      |

One architectural decision from the rewrite is worth calling out specifically: Rekognition never touches S3. Django reads the uploaded file into memory once, and then sends those same raw bytes independently to S3 (for storage) and to Rekognition (for analysis). Two completely separate consumers of the same in-memory buffer — no pipeline between them, no dependency. The old Amplify Lambda called Rekognition with an S3 object reference, which meant Rekognition needed IAM read access to the bucket. The new version sends `Image={"Bytes": image_bytes}` directly. Rekognition gets what it needs from memory. S3 never has to be involved.

Less IAM surface. Fewer moving parts. Cleaner.

---

## Rewriting the Flutter Frontend

Once the backend was Django, every single Amplify SDK call in Flutter needed to go — replaced with plain HTTP calls to the new REST endpoints using the `http` package.

A lot of complexity just evaporated.

The `PhotoGridItem` widget had been a `StatefulWidget` because it needed `initState()` to call `Amplify.Storage.getUrl()` and load the thumbnail URL asynchronously, which meant a loading spinner per grid cell, and N network calls every time the home screen opened. The Django serializer injects the presigned URL directly into the Photo JSON at query time — so now `PhotoGridItem` is a `StatelessWidget` that just does `Image.network(photo.url!)`. No loading state. No extra calls. Gone entirely.

The merge operation went from roughly 50 lines of client-side GraphQL mutations — fetching PhotoPerson links, deduplicating, updating the target person, deleting the source, all manually orchestrated in Dart — down to this:

```dart
final allPeople = await PersonService.listPersons();
// show selection dialog
await PersonService.mergePerson(_person.id, targetPerson.id);
```

Search went from fetching all photos + all persons + all PhotoPerson links and filtering in memory to:

```dart
final results = await PhotoService.search(query);
```

The Amplify codegen models — `Photo.dart`, `Person.dart` — were 300-line files auto-generated from the GraphQL schema. Unreadable, full of Amplify-specific types like `TemporalDateTime`. The replacements are plain Dart classes, hand-written, about 40 lines each. Just `fromJson` factories that map snake_case JSON keys to camelCase Dart properties. That's all they needed to be.

There was also a `_cleanupOrphans()` function running on every People screen load — its job was to find `Person` records with no linked photos, because the Amplify client-side logic had race conditions that occasionally created orphaned persons. The Django backend creates persons atomically inside the upload request, so orphans don't happen. The cleanup function doesn't exist anymore. Neither does the bug it was patching.

---

## The Data Model

Three tables.

`Photo` holds the S3 key, a JSON list of Rekognition `FaceId`s found in the image, a JSON list of detected text lines, and the full bounding box and confidence data for each face. `Person` holds a name (defaults to "Unknown Person" until the user assigns one), a primary `FaceId`, a JSON list of _all_ face IDs accumulated across every photo this person appears in, a bounding box for the face crop, and an S3 key for the thumbnail photo. `PhotoPerson` is the junction table — one row per (photo, person) pair, with a `unique_together` constraint that prevents duplicates at the database level.

That constraint matters. The old Lambda had manual deduplication code to avoid creating the same link twice, because DynamoDB doesn't enforce this. The Django version just puts it in the schema and never thinks about it again.

---

## What It Looks Like to Use

**Photos tab** — date-grouped grid, sticky headers ("Today", "Yesterday", actual dates), 3-column layout. Each thumbnail has small icons overlaid in the corner: a face icon if Rekognition detected faces, a text icon if it found readable text. Tap a photo and you get the full image, a horizontal scrollable row of circular face crops with names beneath them, and a metadata card listing the detected text and timestamps.

**People tab** — split into two sections. The top is a horizontal scroll of unnamed faces — everyone the app has detected but the user hasn't named yet, each with a blue "+" badge. Below that, a grid of named people. Tap anyone and you get their profile: a big face avatar, how many photos they appear in, and a grid of all those photos. Rename and Merge buttons both visible there.

**Search** — Material 3 `SearchBar`, submit triggers the server query, results come back as a photo grid. Type "whiteboard" and get every photo where Rekognition spotted that word. Type someone's name and get their photos too. It's fast because the database does the work.

---

## The Rough Edges

Some parts of this are honestly held together with optimism.

The `baseUrl` in `config.dart` is a hardcoded string. There's no environment variable, no `--dart-define`, no switching between dev and prod. The `ensure_collection()` function — which creates the Rekognition face collection on first deploy — is defined in `ml.py` but never called automatically. You have to run it manually from the Django shell before the first upload. Skip that step and every upload fails with `ResourceNotFoundException`. That's a real bug, not a "known limitation." There's also no token refresh logic: when the 1-day JWT expires, the 401 handler clears tokens and redirects to login. Fine for a course project, broken for anything real.

And there are no tests. The `tests.py` file is the default empty stub. For a project built in this style — incremental commits, lots of iteration, deadline pressure — tests are the thing you always plan to add next sprint.

---

## What I'd Change

The Amplify version bootstrapped fast but created technical debt that lived entirely in the Flutter client — double-encoded JSON fields (a `detectedFaces` value that was a JSON string stored inside a JSON list, requiring two `jsonDecode` calls), client-side search that fetched everything and filtered locally, N+1 thumbnail loading. All of it got fixed in the Django migration. Most of it was avoidable with better API design from the start.

The upload is synchronous and slow — 3 to 7 seconds per photo while Rekognition runs. For two or three users that's tolerable. At any meaningful scale you'd move the Rekognition calls into a background task queue: Celery, Redis as the broker, upload endpoint returns immediately, analysis happens async. The original roadmap actually had Celery in it. It got cut for simplicity. Probably the right call for a semester project, but it's the first thing that would need to change before this handled real traffic.

---

## The Point of It

What I ended up with is a working, end-to-end demonstration of how cloud AI plugs into a standard backend. The insight that's easy to miss: Rekognition's `IndexFaces` doesn't just _detect_ faces, it stores a numerical face embedding vector in a collection and hands you back an ID. `SearchFaces` then does vector similarity search against that collection. You're not writing ML code. You're not training anything. You're calling an API that wraps a model someone else built, and constructing the clustering logic on top of the identifiers it returns.

The AI part of this project is maybe ten lines of Python.

Everything else — how you model the data, how you link faces to persons across thousands of photos, how you expose it cleanly to a mobile frontend, how you handle per-user isolation, how you make merging and renaming feel instant — that's the actual engineering. That's what takes time. That's what breaks in interesting ways.

Weirdly enough, that's the part I found most interesting.
