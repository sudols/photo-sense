# Flutter Frontend — Build Plan

## Context

- **Driver:** Backend migrated to Django REST; Flutter app still calls Amplify SDK
- **Purpose:** Full rewrite of the data layer. Replace every Amplify call with simple HTTP to Django.
- **Scale:** Same 2-3 user educational project
- **Goal:** Simplest possible implementation. No Amplify references left. All business logic on the server.

---

## Stack

| Layer       | Choice                   | Reason                                             |
| ----------- | ------------------------ | -------------------------------------------------- |
| HTTP client | `http` package           | Standard, zero config, sufficient for this scale    |
| Token store | `flutter_secure_storage` | Android Keystore; no plaintext tokens               |
| Auth        | JWT (access only)        | No auto-refresh; 1-day token, re-login on expiry    |
| Models      | Plain Dart classes       | `fromJson`/`toJson` mapping snake_case from Django  |
| State       | `setState`               | Already in use; no need for Riverpod/Bloc for 6 screens |
| Theme       | Material 3 (unchanged)   | Deep Purple seed, light + dark                      |

### Architecture

```
Flutter App (Android)
    |
    | REST + JWT (http package)
    v
Django REST Framework (localhost:8000 / Render)
    |           \
PostgreSQL    boto3 -> S3 (presigned URLs returned in JSON)
              boto3 -> Rekognition (runs on upload)
```

### What Changes vs Amplify

| Amplify (Current)                                        | Django REST (New)                                 | Impact                                 |
| -------------------------------------------------------- | ------------------------------------------------- | -------------------------------------- |
| `Amplify.Auth.signIn()` / Cognito                        | `POST /api/auth/login/` -> JWT                    | Simpler, no AWS dependency             |
| `Amplify.Auth.signUp()` + email verification             | `POST /api/auth/register/` (no verification)      | Drop confirmation code flow            |
| `Amplify.Storage.getUrl()` per photo                     | `photo.url` field in JSON response                | No per-item fetch; URLs come for free  |
| `Amplify.Storage.uploadFile()` + `API.mutate(create)`    | Single `POST /api/photos/upload/` multipart       | 1 call instead of 3                    |
| `ModelQueries.list(Photo.classType)` (GraphQL)           | `GET /api/photos/` (REST JSON)                    | Simpler, no codegen                    |
| Client-side search (fetch all, filter in memory)         | `GET /api/photos/search/?q=text`                  | Server does the work                   |
| Client-side merge (5+ GraphQL mutations)                 | `POST /api/persons/{id}/merge/`                   | 1 call instead of ~10                  |
| Client-side orphan cleanup                               | Not needed (backend creates persons correctly)    | Delete entire `_cleanupOrphans()`      |
| `detectedFaces` as `List<String>` (JSON-in-JSON)         | `detected_faces` as `List<Map>` (native JSON)     | No `jsonDecode` per face               |
| `boundingBox` as JSON-encoded `String`                   | `bounding_box` as `Map` (native JSON)             | No `jsonDecode` on bounding box        |
| Amplify codegen models (300+ lines each)                 | Plain Dart classes (~40 lines each)               | Readable, maintainable                 |
| `TemporalDateTime` (Amplify type)                        | `DateTime.parse()` on ISO 8601 strings            | Standard Dart                          |

---

## Project Structure

```
lib/
├── main.dart                         # App entry (JWT check, no Amplify)
├── config.dart                       # Base URL constant
├── models/
│   ├── photo.dart                    # Plain Dart Photo (fromJson)
│   └── person.dart                   # Plain Dart Person (fromJson)
├── services/
│   ├── api_client.dart               # HTTP wrapper with JWT header
│   ├── auth_service.dart             # Login, register, logout, isLoggedIn
│   ├── photo_service.dart            # List, upload, delete, search
│   └── person_service.dart           # List, detail, rename, merge, delete
├── screens/
│   ├── auth/
│   │   ├── sign_in_screen.dart       # Rewritten (JWT login)
│   │   └── sign_up_screen.dart       # Rewritten (no verification flow)
│   ├── home/
│   │   └── home_screen.dart          # Rewritten (PhotoService, single-call upload)
│   ├── photo/
│   │   └── photo_detail_screen.dart  # Rewritten (presigned URLs, clean JSON, delegated delete)
│   ├── people/
│   │   ├── people_screen.dart        # Rewritten (PersonService, no orphan cleanup)
│   │   ├── person_detail_screen.dart # Rewritten (single-call merge, rename)
│   │   └── name_face_dialog.dart     # Unchanged (pure UI)
│   └── search/
│       └── search_screen.dart        # Rewritten (server-side search)
├── theme/
│   └── app_theme.dart                # Unchanged
└── widgets/
    ├── face_avatar.dart              # Unchanged (pure UI)
    ├── photo_grid_item.dart          # Simplified (use photo.url, no Amplify.Storage)
    └── profile_menu_button.dart      # Simplified (AuthService.logout)
```

---

## Files to Delete

```
lib/amplify_outputs.dart              # Amplify config constants
lib/backend_verification.dart         # Amplify debug tool
lib/models/ModelProvider.dart         # Amplify codegen registry
lib/models/Photo.dart                 # Replaced by models/photo.dart
lib/models/Person.dart                # Replaced by models/person.dart
lib/models/PhotoPerson.dart           # Not needed client-side (backend manages links)
amplify_outputs.dart                  # Root-level Amplify config duplicate
amplify_outputs.json                  # Amplify generated config
amplify/                              # Entire Amplify backend definition directory
.amplify/                             # Amplify cache directory
```

---

## Dependencies

```yaml
# pubspec.yaml — REMOVE these:
#   amplify_flutter: ^2.9.0
#   amplify_auth_cognito: ^2.9.0
#   amplify_storage_s3: ^2.9.0
#   amplify_api: ^2.9.0

# pubspec.yaml — ADD these:
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  google_fonts: ^6.2.1
  image_picker: ^1.2.1
  uuid: ^4.5.2
  flutter_sticky_header: ^0.8.0
  file_picker: ^10.3.10
  http: ^1.2.0                       # REST calls
  flutter_secure_storage: ^9.2.0     # JWT token storage (Android Keystore)
  flutter_speed_dial: ^7.0.0         # FAB menu (was imported but missing from deps)
  intl: ^0.19.0                      # DateFormat (was imported but missing from deps)
```

6 packages removed (all Amplify). 4 packages added. Net: simpler dependency tree.

---

## Configuration

```dart
// lib/config.dart

class AppConfig {
  // Android emulator uses 10.0.2.2 to reach host's localhost.
  // Change to your Render URL for production.
  static const String baseUrl = 'http://10.0.2.2:8000';
  static const String apiUrl = '$baseUrl/api';
}
```

---

## Data Models

### Photo

```dart
// lib/models/photo.dart

class Photo {
  final String id;
  final String s3Key;
  final String? url;
  final List<String> faceIds;
  final List<String> detectedText;
  final List<Map<String, dynamic>> detectedFaces;
  final int facesCount;
  final DateTime? analyzedAt;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Photo({
    required this.id,
    required this.s3Key,
    this.url,
    this.faceIds = const [],
    this.detectedText = const [],
    this.detectedFaces = const [],
    this.facesCount = 0,
    this.analyzedAt,
    required this.createdAt,
    this.updatedAt,
  });

  factory Photo.fromJson(Map<String, dynamic> json) {
    return Photo(
      id: json['id'],
      s3Key: json['s3_key'] ?? '',
      url: json['url'],
      faceIds: List<String>.from(json['face_ids'] ?? []),
      detectedText: List<String>.from(json['detected_text'] ?? []),
      detectedFaces: List<Map<String, dynamic>>.from(
        (json['detected_faces'] ?? []).map((f) => Map<String, dynamic>.from(f)),
      ),
      facesCount: json['faces_count'] ?? 0,
      analyzedAt: json['analyzed_at'] != null
          ? DateTime.parse(json['analyzed_at'])
          : null,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }
}
```

Key differences from Amplify codegen `Photo`:
- 40 lines vs 300 lines
- `detectedFaces` is `List<Map>` not `List<String>` — no `jsonDecode` needed anywhere
- `url` field carries the presigned S3 URL from the serializer — no `Amplify.Storage.getUrl()`
- `DateTime` instead of `TemporalDateTime`
- Snake_case JSON keys mapped to camelCase Dart properties

### Person

```dart
// lib/models/person.dart

import 'photo.dart';

class Person {
  final String id;
  final String name;
  final String faceId;
  final List<String> faceIds;
  final Map<String, dynamic>? boundingBox;
  final String? thumbnailS3Key;
  final String? thumbnailUrl;
  final bool isUnnamed;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<Photo>? photos; // Only populated in detail view

  const Person({
    required this.id,
    required this.name,
    this.faceId = '',
    this.faceIds = const [],
    this.boundingBox,
    this.thumbnailS3Key,
    this.thumbnailUrl,
    this.isUnnamed = true,
    required this.createdAt,
    this.updatedAt,
    this.photos,
  });

  factory Person.fromJson(Map<String, dynamic> json) {
    return Person(
      id: json['id'],
      name: json['name'] ?? 'Unknown Person',
      faceId: json['face_id'] ?? '',
      faceIds: List<String>.from(json['face_ids'] ?? []),
      boundingBox: json['bounding_box'] != null
          ? Map<String, dynamic>.from(json['bounding_box'])
          : null,
      thumbnailS3Key: json['thumbnail_s3_key'],
      thumbnailUrl: json['thumbnail_url'],
      isUnnamed: json['is_unnamed'] ?? true,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
      photos: json['photos'] != null
          ? (json['photos'] as List).map((p) => Photo.fromJson(p)).toList()
          : null,
    );
  }
}
```

Key differences from Amplify codegen `Person`:
- `boundingBox` is `Map<String, dynamic>?` not `String?` — no `jsonDecode` needed
- `thumbnailUrl` carries the presigned URL — no `Amplify.Storage.getUrl()`
- `photos` list included in detail view response — no separate PhotoPerson queries
- No `PhotoPerson` model needed client-side at all

---

## Services

### API Client

```dart
// lib/services/api_client.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config.dart';

class ApiClient {
  static const _storage = FlutterSecureStorage();

  // --- Token management ---

  static Future<void> saveTokens(String access, String refresh) async {
    await _storage.write(key: 'access_token', value: access);
    await _storage.write(key: 'refresh_token', value: refresh);
  }

  static Future<String?> getAccessToken() async {
    return await _storage.read(key: 'access_token');
  }

  static Future<void> clearTokens() async {
    await _storage.deleteAll();
  }

  // --- Headers ---

  static Future<Map<String, String>> _headers({bool json = true}) async {
    final token = await getAccessToken();
    return {
      if (json) 'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // --- HTTP methods ---

  static Future<http.Response> get(String path) async {
    return http.get(
      Uri.parse('${AppConfig.apiUrl}$path'),
      headers: await _headers(),
    );
  }

  static Future<http.Response> post(String path, Map<String, dynamic> body) async {
    return http.post(
      Uri.parse('${AppConfig.apiUrl}$path'),
      headers: await _headers(),
      body: jsonEncode(body),
    );
  }

  static Future<http.Response> patch(String path, Map<String, dynamic> body) async {
    return http.patch(
      Uri.parse('${AppConfig.apiUrl}$path'),
      headers: await _headers(),
      body: jsonEncode(body),
    );
  }

  static Future<http.Response> delete(String path) async {
    return http.delete(
      Uri.parse('${AppConfig.apiUrl}$path'),
      headers: await _headers(),
    );
  }

  /// Multipart file upload.
  /// [fieldName] is the form field name expected by the backend ('file').
  static Future<http.StreamedResponse> multipart(
    String path,
    String filePath,
    String fieldName,
  ) async {
    final uri = Uri.parse('${AppConfig.apiUrl}$path');
    final request = http.MultipartRequest('POST', uri);

    final token = await getAccessToken();
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    request.files.add(await http.MultipartFile.fromPath(fieldName, filePath));
    return request.send();
  }
}
```

No auto-refresh. On 401, screens clear tokens and redirect to login. With a 1-day access token lifetime, this is sufficient.

### Auth Service

```dart
// lib/services/auth_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import 'api_client.dart';

class AuthService {
  /// Login with email and password.
  /// Returns the user's email on success, throws on failure.
  static Future<String> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiUrl}/auth/login/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      await ApiClient.saveTokens(data['access'], data['refresh']);
      return email;
    }

    final error = _extractError(response);
    throw Exception(error);
  }

  /// Register a new account.
  /// Django's RegisterView expects {email, password}.
  static Future<void> register(String email, String password) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiUrl}/auth/register/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode == 201) return;

    final error = _extractError(response);
    throw Exception(error);
  }

  /// Clear stored tokens.
  static Future<void> logout() async {
    await ApiClient.clearTokens();
  }

  /// Check if we have a stored access token.
  static Future<bool> isLoggedIn() async {
    final token = await ApiClient.getAccessToken();
    return token != null;
  }

  static String _extractError(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map) {
        // SimpleJWT returns {"detail": "..."} on error
        if (body.containsKey('detail')) return body['detail'];
        // RegisterView returns {"error": "..."}
        if (body.containsKey('error')) return body['error'];
        // Field-level errors: {"username": ["..."]}
        return body.values.first.toString();
      }
    } catch (_) {}
    return 'Request failed (${response.statusCode})';
  }
}
```

No email verification flow. Django creates the user immediately on register. The sign-up screen redirects to sign-in on success.

### Photo Service

```dart
// lib/services/photo_service.dart

import 'dart:convert';
import '../models/photo.dart';
import 'api_client.dart';

class PhotoService {
  /// Fetch all photos for the current user.
  /// Backend returns newest first, with presigned URLs.
  static Future<List<Photo>> listPhotos() async {
    final response = await ApiClient.get('/photos/');
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((j) => Photo.fromJson(j)).toList();
    }
    throw Exception('Failed to load photos (${response.statusCode})');
  }

  /// Upload a photo file.
  /// Backend handles: S3 upload + Rekognition analysis + Person creation.
  /// Returns the created Photo with presigned URL.
  static Future<Photo> uploadPhoto(String filePath) async {
    final response = await ApiClient.multipart('/photos/upload/', filePath, 'file');
    final body = await response.stream.bytesToString();

    if (response.statusCode == 201) {
      return Photo.fromJson(jsonDecode(body));
    }
    throw Exception('Upload failed (${response.statusCode})');
  }

  /// Delete a photo by ID.
  /// Backend handles: S3 deletion + orphan person cleanup.
  static Future<void> deletePhoto(String id) async {
    final response = await ApiClient.delete('/photos/$id/');
    if (response.statusCode == 204) return;
    throw Exception('Delete failed (${response.statusCode})');
  }

  /// Server-side search by detected text or person name.
  static Future<List<Photo>> search(String query) async {
    final response = await ApiClient.get(
      '/photos/search/?q=${Uri.encodeComponent(query)}',
    );
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((j) => Photo.fromJson(j)).toList();
    }
    throw Exception('Search failed (${response.statusCode})');
  }
}
```

### Person Service

```dart
// lib/services/person_service.dart

import 'dart:convert';
import '../models/person.dart';
import 'api_client.dart';

class PersonService {
  /// List all persons for the current user.
  /// Does NOT include photos (lightweight for grid view).
  static Future<List<Person>> listPersons() async {
    final response = await ApiClient.get('/persons/');
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((j) => Person.fromJson(j)).toList();
    }
    throw Exception('Failed to load persons (${response.statusCode})');
  }

  /// Get a single person with their photos included.
  static Future<Person> getPerson(String id) async {
    final response = await ApiClient.get('/persons/$id/');
    if (response.statusCode == 200) {
      return Person.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to load person (${response.statusCode})');
  }

  /// Rename a person and mark as named.
  static Future<Person> renamePerson(String id, String name) async {
    final response = await ApiClient.patch('/persons/$id/', {
      'name': name,
      'is_unnamed': false,
    });
    if (response.statusCode == 200) {
      return Person.fromJson(jsonDecode(response.body));
    }
    throw Exception('Rename failed (${response.statusCode})');
  }

  /// Merge source person into target.
  /// Backend handles: combine face_ids, re-link PhotoPersons, delete source.
  static Future<void> mergePerson(String sourceId, String targetId) async {
    final response = await ApiClient.post('/persons/$sourceId/merge/', {
      'merge_into_id': targetId,
    });
    if (response.statusCode == 200) return;
    throw Exception('Merge failed (${response.statusCode})');
  }

  /// Delete a person.
  static Future<void> deletePerson(String id) async {
    final response = await ApiClient.delete('/persons/$id/');
    if (response.statusCode == 204) return;
    throw Exception('Delete failed (${response.statusCode})');
  }
}
```

Compare merge: Amplify version is ~50 lines of client-side GraphQL mutations. Django version is 4 lines.

---

## Screens

### main.dart

```dart
// lib/main.dart

import 'package:flutter/material.dart';
import 'screens/auth/sign_in_screen.dart';
import 'screens/home/home_screen.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PhotoSenseApp());
}

class PhotoSenseApp extends StatelessWidget {
  const PhotoSenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PhotoSense',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const AuthCheck(),
    );
  }
}

class AuthCheck extends StatefulWidget {
  const AuthCheck({super.key});

  @override
  State<AuthCheck> createState() => _AuthCheckState();
}

class _AuthCheckState extends State<AuthCheck> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final loggedIn = await AuthService.isLoggedIn();
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => loggedIn ? const HomeScreen() : const SignInScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
```

Removed: `_configureAmplify()`, all Amplify imports, `ModelProvider`. Replaced with a single `AuthService.isLoggedIn()` check.

### Sign In Screen

```dart
// lib/screens/auth/sign_in_screen.dart

import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../home/home_screen.dart';
import 'sign_up_screen.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final email = await AuthService.login(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ... UI is identical to current sign_in_screen.dart
    // Only change: removed hardcoded test credentials from TextEditingController
    // _emailController = TextEditingController()  (was: 'demo@example.com')
    // _passwordController = TextEditingController()  (was: 'test_password_123')
    // The rest of the build method (logo, form fields, sign-up link) stays the same.
    // See current lib/screens/auth/sign_in_screen.dart build() — copy as-is minus the default values.
  }
}
```

Changes: Removed hardcoded credentials. `AuthService.signIn()` -> `AuthService.login()` (returns email string, stores JWT internally). No Amplify imports.

### Sign Up Screen

```dart
// lib/screens/auth/sign_up_screen.dart

import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import 'sign_in_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // REMOVED: _codeController, _needsConfirmation, _confirmSignUp()
  // Django creates the user immediately — no email verification flow.

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await AuthService.register(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Account created! Please sign in.'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
        Navigator.of(context).pop(); // Back to sign-in
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ... UI is the sign-up form only (_buildSignUpForm from current code).
    // REMOVED: _buildConfirmationForm (no verification).
    // REMOVED: _needsConfirmation ternary in body.
    // The form fields (email, password, confirm password, create account button) stay the same.
    // See current lib/screens/auth/sign_up_screen.dart _buildSignUpForm() — copy as-is.
  }
}
```

Changes: Deleted `_confirmSignUp()`, `_codeController`, `_needsConfirmation`, `_buildConfirmationForm()`. Removed `Amplify.Auth.confirmSignUp` import. The screen is now just the sign-up form.

### Home Screen

Key changes from current `home_screen.dart`:

```dart
// What changes in lib/screens/home/home_screen.dart:

// REMOVED imports:
//   amplify_flutter, amplify_api, amplify_storage_s3
//   models/Photo.dart (Amplify codegen)

// ADDED imports:
//   services/photo_service.dart
//   models/photo.dart (plain Dart)
//   services/auth_service.dart

// REMOVED: _loadUserAndPhotos() fetching Amplify.Auth.fetchUserAttributes()
// The email can be stored at login time or omitted (minor).

// _fetchPhotos() changes from:
//   final request = ModelQueries.list(Photo.classType);
//   final response = await Amplify.API.query(request: request).response;
//   final photos = response.data!.items.whereType<Photo>().toList();
// to:
//   final photos = await PhotoService.listPhotos();
// That's it. Backend returns newest-first, with presigned URLs.

// _uploadPhoto() changes from:
//   1. Amplify.Storage.uploadFile(localFile, path)
//   2. Amplify.API.mutate(ModelMutations.create(newPhoto))
// to:
//   await PhotoService.uploadPhoto(pickedFile.path);
// Single call. Backend handles S3 + Rekognition + DB.

// _uploadCollection() same pattern — loop over files, call PhotoService.uploadPhoto() each.

// _groupPhotosByDate() changes:
//   photo.createdAt?.getDateTimeInUtc().toLocal()
// to:
//   photo.createdAt.toLocal()
// (DateTime instead of TemporalDateTime)

// PhotoGridItem receives the same Photo object.
// Photo now has .url so PhotoGridItem doesn't need Amplify.Storage.getUrl().
```

### Photo Detail Screen

Key changes from current `photo_detail_screen.dart`:

```dart
// What changes in lib/screens/photo/photo_detail_screen.dart:

// REMOVED imports: amplify_flutter, amplify_api, amplify_storage_s3, models/PhotoPerson.dart

// ADDED imports: services/photo_service.dart, services/person_service.dart

// REMOVED: _loadImageUrl()
// Photo already has .url (presigned) from the list endpoint.
// Use widget.photo.url directly in Image.network().

// _loadFaceData() changes from:
//   widget.photo.detectedFaces!.map((f) => jsonDecode(f)['faceId'])
// to:
//   widget.photo.detectedFaces.map((f) => f['face_id'] as String)
// No jsonDecode — detectedFaces is already List<Map>.
//
// Person lookup stays the same pattern:
//   final persons = await PersonService.listPersons();
//   for (var person in persons) {
//     for (var faceId in faceIds) {
//       if (person.faceIds.contains(faceId)) {
//         _facePersons[faceId] = person;
//       }
//     }
//   }

// _handleFaceTap() rename flow changes from:
//   await Amplify.API.mutate(ModelMutations.update(person.copyWith(name: ..., isUnnamed: false)))
// to:
//   await PersonService.renamePerson(person.id, name);
// Single call.

// _deletePhoto() changes from:
//   1. Query PhotoPerson links
//   2. Delete each link
//   3. Check orphaned persons, delete or update thumbnails
//   4. Amplify.Storage.remove()
//   5. Amplify.API.mutate(ModelMutations.delete(photo))
// to:
//   await PhotoService.deletePhoto(widget.photo.id);
// Single call. Backend handles all cleanup.

// Face list rendering changes from:
//   final face = jsonDecode(widget.photo.detectedFaces![index]);
//   final faceId = face['faceId'] as String;
//   final box = face['boundingBox'];
// to:
//   final face = widget.photo.detectedFaces[index];
//   final faceId = face['face_id'] as String;
//   final box = face['bounding_box'];
// No jsonDecode. Note: snake_case keys from Django.

// Metadata display changes:
//   widget.photo.analyzedAt!.format()  ->  widget.photo.analyzedAt.toString()
//   widget.photo.createdAt!.format()   ->  widget.photo.createdAt.toString()
```

### People Screen

Key changes from current `people_screen.dart`:

```dart
// What changes in lib/screens/people/people_screen.dart:

// REMOVED imports: amplify_flutter, amplify_api, amplify_storage_s3, models/PhotoPerson.dart
// ADDED imports: services/person_service.dart, models/person.dart

// _loadPeople() changes from:
//   final request = ModelQueries.list(Person.classType);
//   final response = await Amplify.API.query(request: request).response;
//   final people = response.data?.items.whereType<Person>().toList() ?? [];
// to:
//   final people = await PersonService.listPersons();

// REMOVED: _loadThumbnails()
// Person already has .thumbnailUrl (presigned) from the serializer.

// REMOVED: _cleanupOrphans()
// Backend creates persons correctly. No orphans to clean up.

// _buildPersonItem() changes:
//   final imageUrl = _thumbnailUrls[person.id];
// to:
//   final imageUrl = person.thumbnailUrl;
//
//   box = jsonDecode(person.boundingBox!);
// to:
//   box = person.boundingBox ?? {};
// No jsonDecode — boundingBox is already Map.
```

### Person Detail Screen

Key changes from current `person_detail_screen.dart`:

```dart
// What changes in lib/screens/people/person_detail_screen.dart:

// REMOVED imports: amplify_flutter, amplify_api, amplify_storage_s3, models/PhotoPerson.dart
// ADDED imports: services/person_service.dart, services/photo_service.dart

// REMOVED: _loadThumbnail() via Amplify.Storage.getUrl()
// Person already has .thumbnailUrl.

// _loadPhotos() changes from:
//   1. Query PhotoPerson links for this person
//   2. Fetch each Photo individually by ID
//   3. Broken link cleanup
//   4. Fetch presigned URLs for each photo
// to:
//   final person = await PersonService.getPerson(widget.person.id);
//   _person = person;
//   _photos = person.photos ?? [];
// Single call. Backend returns person with nested photos (each with presigned URL).
// No PhotoPerson queries. No _loadPhotoUrls(). No broken link cleanup.

// _handleMerge() changes from:
//   1. Fetch all people via GraphQL
//   2. Show selection dialog
//   3. Confirm dialog
//   4. Update target person's faceIds via GraphQL mutation
//   5. Query source's PhotoPerson links
//   6. Query target's PhotoPerson links (avoid duplicates)
//   7. For each link: delete old, create new
//   8. Delete source person
//   (~50 lines of client-side logic)
// to:
//   1. Fetch all people: final allPeople = await PersonService.listPersons();
//   2. Show selection dialog (same UI)
//   3. Confirm dialog (same UI)
//   4. await PersonService.mergePerson(_person.id, targetPerson.id);
//   (~4 lines of service calls, same UI)

// _handleRename() changes from:
//   1. Query persons with same name via GraphQL
//   2. If exists, prompt merge (duplicated 30-line merge logic)
//   3. If not, update via GraphQL mutation
// to:
//   1. await PersonService.renamePerson(_person.id, newName);
//   Backend can be extended to handle name-conflict merge if needed.
//   For now, simple rename. If user wants to merge, they use the Merge button.

// build() boundingBox changes:
//   box = jsonDecode(_person.boundingBox!);
// to:
//   box = _person.boundingBox ?? {};

// Photo grid item URL changes:
//   final url = _photoUrls[photo.id];
// to:
//   final url = photo.url;
```

### Search Screen

Key changes from current `search_screen.dart`:

```dart
// What changes in lib/screens/search/search_screen.dart:

// REMOVED imports: amplify_flutter, amplify_api, amplify_storage_s3
// REMOVED imports: models/Person.dart, models/PhotoPerson.dart
// ADDED imports: services/photo_service.dart, models/photo.dart

// REMOVED: _photoUrls map, _loadPhotoUrls()
// Photos come with .url from the backend.

// _performSearch() changes from:
//   1. Fetch ALL photos via GraphQL
//   2. Filter detectedText client-side
//   3. Fetch ALL persons via GraphQL
//   4. Filter persons by name client-side
//   5. For each matched person, query PhotoPerson links via GraphQL
//   6. For each link, find or fetch the photo
//   7. Deduplicate, sort
//   (~50 lines)
// to:
//   final results = await PhotoService.search(query);
//   setState(() { _searchResults = results; _isSearching = false; });
//   (~3 lines)
// Backend handles text search + person name search + dedup.

// Grid item rendering changes:
//   final url = _photoUrls[photo.id];
// to:
//   final url = photo.url;
```

---

## Widget Changes

### photo_grid_item.dart

```dart
// lib/widgets/photo_grid_item.dart

import 'package:flutter/material.dart';
import '../models/photo.dart';

/// Grid item displaying a photo thumbnail.
/// URL comes from photo.url (presigned, from Django serializer).
class PhotoGridItem extends StatelessWidget {
  final Photo photo;
  final VoidCallback onTap;

  const PhotoGridItem({
    super.key,
    required this.photo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (photo.url != null)
            Image.network(
              photo.url!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Center(
                child: Icon(Icons.broken_image_outlined,
                    color: colorScheme.onSurfaceVariant, size: 40),
              ),
            )
          else
            Center(
              child: Icon(Icons.image_not_supported_outlined,
                  color: colorScheme.onSurfaceVariant, size: 40),
            ),

          // Bottom overlay with info
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                  ],
                ),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  if (photo.facesCount > 0) ...[
                    const Icon(Icons.face, color: Colors.white, size: 12),
                    const SizedBox(width: 4),
                    Text('${photo.facesCount}',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 10)),
                    const SizedBox(width: 8),
                  ],
                  if (photo.detectedText.isNotEmpty)
                    const Icon(Icons.text_fields,
                        color: Colors.white, size: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

Changes: Converted from `StatefulWidget` to `StatelessWidget`. Removed `_loadImageUrl()` and `Amplify.Storage.getUrl()`. Uses `photo.url` directly. No loading spinner needed per item.

### profile_menu_button.dart

```dart
// lib/widgets/profile_menu_button.dart

import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../screens/auth/sign_in_screen.dart';

class ProfileMenuButton extends StatefulWidget {
  final String? userEmail;

  const ProfileMenuButton({super.key, this.userEmail});

  @override
  State<ProfileMenuButton> createState() => _ProfileMenuButtonState();
}

class _ProfileMenuButtonState extends State<ProfileMenuButton> {
  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await AuthService.logout();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SignInScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // ... Identical to current build() method.
    // Only change: AuthService.signOut() -> AuthService.logout().
    // The Amplify import is removed.
  }
}
```

Changes: Removed `amplify_flutter` import. `AuthService.signOut()` -> `AuthService.logout()`. UI unchanged.

### face_avatar.dart — Unchanged

Pure UI widget. Takes `imageUrl`, `boundingBox` (Map), renders cropped face circle. No backend calls. No changes needed.

### name_face_dialog.dart — Unchanged

Pure UI widget. Shows text field, returns name string. No backend calls. No changes needed.

---

## Running Locally

```bash
# 1. Start Django backend
cd backend
source venv/bin/activate
python manage.py runserver              # runs on :8000

# 2. Run Flutter app (separate terminal)
cd ..                                   # back to photo_sense/
flutter run                             # targets Android emulator
```

`AppConfig.baseUrl` is `http://10.0.2.2:8000` — Android emulator's alias for host localhost.

---

## Build Phases

### Phase 1 — Dependencies + Cleanup

- [ ] Create `frontend` branch from `django-backend`
- [ ] Remove `amplify_flutter`, `amplify_auth_cognito`, `amplify_storage_s3`, `amplify_api` from `pubspec.yaml`
- [ ] Add `http`, `flutter_secure_storage`, `flutter_speed_dial`, `intl` to `pubspec.yaml`
- [ ] Delete Amplify files: `lib/amplify_outputs.dart`, `lib/backend_verification.dart`, `amplify_outputs.dart`, `amplify_outputs.json`
- [ ] Delete Amplify directories: `amplify/`, `.amplify/`
- [ ] Delete Amplify codegen models: `lib/models/ModelProvider.dart`, `lib/models/Photo.dart`, `lib/models/Person.dart`, `lib/models/PhotoPerson.dart`
- [ ] Run `flutter pub get` — verify no Amplify references in resolved deps

### Phase 2 — Models + Config

- [ ] Write `lib/config.dart`
- [ ] Write `lib/models/photo.dart`
- [ ] Write `lib/models/person.dart`
- [ ] Verify: `flutter analyze` passes on new files

### Phase 3 — Services + Auth Screens

- [ ] Write `lib/services/api_client.dart`
- [ ] Write `lib/services/auth_service.dart`
- [ ] Rewrite `lib/main.dart` (remove Amplify, JWT check)
- [ ] Rewrite `lib/screens/auth/sign_in_screen.dart` (remove hardcoded creds, use AuthService.login)
- [ ] Rewrite `lib/screens/auth/sign_up_screen.dart` (remove verification flow, use AuthService.register)
- [ ] Rewrite `lib/widgets/profile_menu_button.dart` (AuthService.logout)
- [ ] Test: register -> login -> token stored -> HomeScreen shown

### Phase 4 — Photo Service + Home Screen

- [ ] Write `lib/services/photo_service.dart`
- [ ] Rewrite `lib/widgets/photo_grid_item.dart` (StatelessWidget, use photo.url)
- [ ] Rewrite `lib/screens/home/home_screen.dart` (PhotoService, single-call upload)
- [ ] Test: photos load in grid, upload works, date grouping works

### Phase 5 — Photo Detail + Face Handling

- [ ] Rewrite `lib/screens/photo/photo_detail_screen.dart`
  - Presigned URL from photo.url
  - Clean JSON (no jsonDecode on faces)
  - Single-call delete via PhotoService
  - Face-person matching via PersonService.listPersons()
  - Rename via PersonService.renamePerson()
- [ ] Test: photo detail loads, faces display with names, delete works

### Phase 6 — People + Search

- [ ] Write `lib/services/person_service.dart`
- [ ] Rewrite `lib/screens/people/people_screen.dart` (PersonService, no orphan cleanup, no thumbnail fetch)
- [ ] Rewrite `lib/screens/people/person_detail_screen.dart` (single-call merge, single-call rename, person.photos)
- [ ] Rewrite `lib/screens/search/search_screen.dart` (server-side search, 3 lines)
- [ ] Test: people grid loads, merge works, rename works, search returns results

### Phase 7 — Polish + End-to-End

- [ ] `grep -r "amplify" lib/` — verify zero Amplify references
- [ ] `grep -r "Amplify" lib/` — verify zero Amplify references
- [ ] `flutter analyze` — zero warnings
- [ ] End-to-end: register -> login -> upload photo -> view detail -> name face -> search by text -> search by person -> merge persons -> delete photo -> sign out
- [ ] Handle 401 gracefully: clear tokens, redirect to sign-in

---

## Improvements Over Amplify Frontend

| Issue (Amplify)                                            | Fix (Django REST)                                       |
| ---------------------------------------------------------- | ------------------------------------------------------- |
| `Amplify.Storage.getUrl()` called per photo (N+1 network)  | `photo.url` included in list response (0 extra calls)   |
| 3-step upload: S3 presign -> PUT -> AppSync create          | Single `POST /api/photos/upload/` multipart             |
| Search fetches ALL photos, filters in memory                | `GET /api/photos/search/?q=` — server does the work     |
| Merge requires ~10 GraphQL mutations client-side            | `POST /api/persons/{id}/merge/` — 1 call                |
| Orphan cleanup runs on every People screen open             | Not needed — backend creates persons correctly           |
| `detectedFaces` double-encoded (JSON string in JSON list)   | Native JSON — `List<Map>` directly                      |
| `boundingBox` is JSON-encoded string, requires `jsonDecode` | Native `Map` from serializer                            |
| 300-line Amplify codegen models                             | 40-line plain Dart classes                              |
| `PhotoGridItem` is StatefulWidget (loads URL on init)       | StatelessWidget (URL already available)                 |
| Missing deps (flutter_speed_dial, intl) cause build errors  | All deps declared in pubspec.yaml                       |
| Hardcoded test credentials in sign-in screen                | Removed                                                 |
| Email verification flow (Cognito-specific)                  | Dropped — Django creates user immediately               |
| Requires AWS Cognito + AppSync + S3 IAM for any testing     | Just `python manage.py runserver` + `flutter run`       |
