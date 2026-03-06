# PhotoSense Project Tracking

This file tracks implementation progress and known issues for the PhotoSense application.

## Project Status Overview

- **Backend**: Django REST Framework (migrated from AWS Amplify)
- **Frontend**: Flutter — fully rewired to Django REST API
- **Status**: Django migration **COMPLETE** and merged to main.

---
## Known Issues & Technical Debt

### Critical / High — Address in follow-up

| # | Area | File | Issue |
|---|------|------|-------|
| 1 | Flutter | `lib/screens/home/home_screen.dart:26` | `_userEmail` is always `null`. Profile avatar always shows "U". Login returns email but `HomeScreen` never receives it. Fix: store email in secure storage during login and read it in `HomeScreen.initState`. |
| 2 | Flutter | `lib/services/api_client.dart` | No token refresh logic. The stored refresh token is never used. When the 1-day access token expires, the 401 handler silently logs out the user. Fix: intercept 401, attempt `POST /api/auth/refresh/`, retry the original request, then clear tokens only if refresh also fails. |
| 3 | Django | `backend/photos/ml.py:15-20` | `ensure_collection()` is defined but never called. If the Rekognition collection `photosense-faces` does not exist, all face indexing will fail with `ResourceNotFoundException`. Fix: call at startup (e.g. `AppConfig.ready()`) or as a management command. |
| 4 | Django | `backend/photos/ml.py:68-69` | `search_faces()` silently swallows all exceptions with a bare `except: pass`. Network errors, throttling, and credential failures are invisible. Fix: log the exception at minimum; surface Rekognition errors to the caller. |
| 5 | Django | `backend/photosense/settings.py:19` | `ALLOWED_HOSTS = ["*"]` in production allows HTTP Host header attacks. Fix: restrict to the actual Render domain before public deployment. |

### Medium — Address soon

| # | Area | File | Issue |
|---|------|------|-------|
| 6 | Flutter | `lib/config.dart:5` | `baseUrl` is a hardcoded compile-time constant (`localhost:8000`). No environment switching. Fix: use `String.fromEnvironment('API_URL', defaultValue: '...')` with `--dart-define` per build target. |
| 7 | Django | `backend/photos/auth_views.py:15` | `RegisterView` only checks non-empty fields. Django's built-in password validators (configured in `settings.py`) are not applied. Users can register with a single-character password. Fix: call `validate_password()` in the view. |
| 8 | Django | `backend/photos/views.py:88` | `PhotoViewSet` inherits `ModelViewSet`, exposing `POST /api/photos/` (bypasses S3/Rekognition) and `PUT/PATCH /api/photos/{id}/` (no valid use case). Fix: restrict to `ListModelMixin + RetrieveModelMixin + DestroyModelMixin`. |
| 9 | Django | `backend/photos/views.py:94-96` | Deleting a photo cascades `PhotoPerson` links but does not delete `Person` records with no remaining photos. Orphan persons accumulate. Fix: after destroy, delete persons whose `photo_persons` count is zero. |
| 10 | Flutter | `lib/services/auth_service.dart:47-49` | `isLoggedIn()` only checks token existence, not expiry. An expired stored token passes the check, leading to a 401 on the first API call. Fix: decode the JWT and check the `exp` claim locally. |

### Low — Code quality

| # | Area | File | Issue |
|---|------|------|-------|
| 11 | Flutter | `pubspec.yaml:16` | `uuid: ^4.5.2` is listed but never imported or used. Remove. |
| 12 | Flutter | `pubspec.yaml:13` | `cupertino_icons: ^1.0.8` is listed but never imported. Remove if not needed. |
| 13 | Django | `backend/requirements.txt` | `Pillow` is listed but never used in any source file. Remove or implement planned thumbnail generation. |
| 14 | Flutter | `lib/widgets/face_avatar.dart:38-128` | ~90 lines of inline exploratory dev comments ("Let's try...", "Actually..."). Clean up before any public release. |
| 15 | Flutter | `lib/screens/search/search_screen.dart:80-88` | Hardcoded `Colors.grey[400/600]` instead of theme `colorScheme` colors. Inconsistent with rest of app. |
| 16 | Django | `backend/photos/tests.py` | No tests exist. Add unit tests for upload, face clustering, merge, and auth flows. |
| 17 | Repo | `.gitignore:57-78` | Vestigial Amplify-related gitignore patterns remain. Harmless but can be cleaned up. |

---

## Backlog Features (Not Yet Implemented)

- [ ] Manually tag multiple photos with a specific person
- [ ] Infinite scroll / pagination for large photo libraries
- [ ] Filters (by date range, has text, has faces, specific person)
- [ ] On-device image caching to reduce network calls
- [ ] Background upload with progress indicator
- [ ] Basic analytics (photo count, unique people, most common words)
- [ ] Whitenoise middleware for Django static file serving
- [ ] CORS allowed origins configured for production

---

## Endpoint Reference

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/auth/register/` | Create new user account |
| POST | `/api/auth/login/` | Obtain JWT access + refresh tokens |
| POST | `/api/auth/refresh/` | Refresh access token |
| GET | `/api/photos/` | List user's photos |
| POST | `/api/photos/upload/` | Upload photo (S3 + Rekognition analysis) |
| GET | `/api/photos/{id}/` | Retrieve single photo |
| DELETE | `/api/photos/{id}/` | Delete photo (S3 + DB) |
| GET | `/api/photos/search/?q=` | Search photos by detected text |
| GET | `/api/persons/` | List user's persons |
| GET | `/api/persons/{id}/` | Retrieve person with their photos |
| PATCH | `/api/persons/{id}/` | Rename person |
| DELETE | `/api/persons/{id}/` | Delete person |
| POST | `/api/persons/{id}/merge/` | Merge person into another |
