# PhotoSense — Project Roadmap

## 1. Project Overview

PhotoSense is a Flutter-based photo gallery app that lets users:

- Upload photos
- Automatically detect and identify people using face recognition
- Automatically extract visible text (OCR) from photos
- Search photos by person name or detected text

---

## 2. Completed (Amplify MVP)

The initial version of the app was built on AWS Amplify (serverless stack) and is fully functional.

### What was built

- [x] User sign-up / sign-in (AWS Cognito)
- [x] Photo upload to S3
- [x] Automatic face detection and indexing (AWS Rekognition — `IndexFaces`)
- [x] Automatic OCR text extraction (AWS Rekognition — `DetectText`)
- [x] Face clustering into Person entities (Unknown Person grouping)
- [x] Assign names to unknown persons
- [x] Photos tab — grid view grouped by date
- [x] People tab — list of identified and unnamed persons
- [x] Person detail screen — all photos containing that person
- [x] Search tab — search by person name or detected text
- [x] Per-user data isolation (owner-based auth)

### Amplify stack used

| Layer | Service |
|---|---|
| Auth | AWS Cognito (User Pool + Identity Pool) |
| Storage | Amazon S3 |
| API | AWS AppSync (GraphQL) |
| Database | Amazon DynamoDB |
| Processing | AWS Lambda (TypeScript, S3-triggered) |
| AI/ML | Amazon Rekognition |
| Framework | AWS Amplify Gen 2 |

---

## 3. Current Direction — Django Migration

The backend is being migrated from the Amplify serverless stack to a Django-based backend. This is driven by course requirements (Django is covered in the course curriculum).

See `DJANGO_MIGRATION.md` for the full migration plan, code, and phase-by-phase breakdown.

### Why migrate

- Course requirement: Django is the framework covered in the curriculum
- Django gives a better foundation for learning backend concepts (ORM, admin, REST, signals)
- Easier manual testing via Django Admin and Django shell
- Standard PostgreSQL database instead of DynamoDB
- Simpler to explain and demonstrate to professors

### What stays the same

| Component | Decision |
|---|---|
| S3 (photo storage) | Keep — same bucket, same boto3 SDK |
| AWS Rekognition | Keep — same API calls, just via boto3 in Python |
| Flutter frontend | Keep — update API calls from GraphQL to REST |
| Core data model | Keep — Photo, Person, PhotoPerson (same structure) |

### What changes

| Current (Amplify) | New (Django) |
|---|---|
| AppSync (GraphQL) | Django REST Framework |
| DynamoDB | PostgreSQL |
| Lambda (S3-triggered) | Celery worker (signal-triggered) |
| Amplify Auth (Cognito) | Django JWT auth |
| Amplify SDK in Flutter | dio HTTP client in Flutter |

---

## 4. Django Migration Phases

| Phase | Goal | Status |
|---|---|---|
| 1 — Setup & Models | Django project, PostgreSQL models, Django Admin | Pending |
| 2 — REST API | DRF serializers, viewsets, JWT auth | Pending |
| 3 — Rekognition + Celery | boto3 ML wrapper, async task, signals | Pending |
| 4 — Data Migration | Export DynamoDB, import to PostgreSQL | Pending |
| 5 — Flutter Update | Replace Amplify SDK with REST + JWT | Pending |
| 6 — Polish & Demo | Error handling, demo prep, optional deploy | Pending |

---

## 5. Remaining Flutter Features (Backlog)

These were planned in the original roadmap but not yet implemented. They apply regardless of backend stack.

- [ ] Manually tag multiple photos with a specific person
- [ ] Infinite scroll for large photo libraries
- [ ] Filters (by date range, has text, has faces, specific person)
- [ ] On-device image caching to reduce network calls
- [ ] Background upload with progress indicator
- [ ] Basic analytics (photo count, unique people, most common words)

---

## 6. Technical Debt / Known Limitations

| Item | Description | Priority |
|---|---|---|
| Face lookup is O(N) | Person table is scanned to find matching face IDs. Should use a indexed lookup (GSI in DynamoDB or DB index in PostgreSQL). | Low — acceptable at personal scale |
| No real-time updates | Flutter polls for new data rather than using subscriptions. AppSync subscriptions are removed in Django migration. | Low |
| No offline support | App requires network for all operations | Low |
