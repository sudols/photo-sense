# PhotoSense: Intelligent Photo Gallery with People & Text Search

## 1. Project Overview

PhotoSense is a Flutter-based photo gallery app that lets users:

- Upload photos
- Automatically detect and identify people using face recognition
- Automatically extract visible text (OCR) from photos
- Search photos by person name or detected text

The backend is built entirely on AWS, using Amazon Rekognition for both face analysis and text detection, providing a single service for face collections (index/search) and OCR. [web:67][web:152][web:254]

---

## 2. Current Phase (MVP Scope)

This phase is a **small, demo-focused** version of the app that proves the core pipeline works end-to-end.

### 2.1 Features to Implement Now (Short Mock)

- [x] **User Account**
  - Simple sign-up/sign-in using AWS Cognito (via Amplify Auth).
- [x] **Photo Upload**
  - Pick photo from local gallery in Flutter.
  - Upload image to an S3 bucket using Amplify Storage. [web:160][web:273]
- [x] **Backend Analysis**
  - Invoke a REST API backed by AWS Lambda to analyze the uploaded image.
  - Lambda calls Amazon Rekognition:
    - `IndexFaces` to detect and index faces into a Rekognition collection. [web:67][web:22]
    - `DetectText` to extract visible text from the image. [web:152]
- [x] **Metadata Storage**
  - Store basic metadata for each photo in a database (e.g., AppSync + DynamoDB/GraphQL API):
    - `photoId`
    - `s3Key`
    - `faceIds` (from Rekognition)
    - `detectedText` (list of strings)
    - `createdAt`
- [x] **UI**
  - Simple home screen with:
    - Upload button
    - Grid view of all photos (thumbnails via signed S3 URLs)
    - Tap a photo → show:
      - Detected faces count
      - Extracted text list

This MVP **does not yet** include:

- Named people (no “John”, “Alice” labels yet)
- Full People tab
- Full Search tab
- Grouping/merging of identities

---

## 3. Future Phase (Full Project Vision)

The future phase turns the MVP into a more complete photo-organizing app with people and text search.

### 3.1 Planned Features

- **People Management**
  - [x] Map Rekognition face IDs to **Person** entities with human-assigned names.
  - [x] “People” tab listing:
    - [x] Identified people (with names and photo counts)
    - [x] Unidentified groups (clusters of faces without names)
  - Ability to:
    - [x] Assign a name to an unidentified person/group
    - [x] Merge duplicate people

- **Search**
  - [x] “Search” tab where user can:
    - [x] Search photos by person name (using Person ↔ Photo links).
    - [x] Search photos by text content (using `detectedText` stored for each photo).

- **Manual Tagging & Grouping**
  - From Photos tab:
    - [ ] Manually select multiple photos and link them to a specific Person.
  - Support for viewing all photos for a given Person.
    - [x] (Implemented in Person Detail Screen)

- **Advanced UX**
  - [ ] Infinite scroll grid for large libraries.
  - [ ] Filters (by date range, has text / has faces / specific person).
  - [ ] Optional folder concepts (logical groupings based on tags, not device file system).

- **Optional Enhancements**
  - On-device caching to reduce network calls.
  - Background upload and analysis.
  - Basic analytics (photo count, unique people, most common words).

---

## 4. Architecture Overview

### 4.1 High-Level Components

- **Flutter App (Client)**
  - UI (three tabs in future phase): Photos, People, Search.
  - Local image picking and upload.
  - Auth flows (Cognito).
  - REST + GraphQL/API calls via Amplify.

- **AWS Services (Backend)**
  - **Amazon Cognito**: user authentication/identity for controlling S3/API access. [web:261]
  - **Amazon S3**: stores original photo files. [web:273]
  - **AWS Lambda**: serverless functions that:
    - Read images from S3.
    - Call Amazon Rekognition APIs.
    - Return analysis results to the app or write to DB. [web:148]
  - **Amazon Rekognition**:
    - `IndexFaces` + `SearchFacesByImage` for face indexing and matching. [web:67][web:22]
    - `DetectText` for OCR-like text detection in images. [web:152][web:119]
  - **AppSync + DynamoDB (or REST + DynamoDB)**:
    - Stores photo, person, and linking metadata.
    - Supports efficient queries for Photos, People, and Search.

---

## 5. Tech & Services Used

### 5.1 Frontend

- **Framework**: Flutter (Dart)
- **State Management**: (TBD – e.g., Provider, Riverpod, Bloc)
- **Image Picker**: `image_picker` plugin for selecting photos from device gallery.

### 5.2 AWS Backend

- **AWS Amplify (Flutter)**
  - Used to configure and connect:
    - Auth (Cognito)
    - Storage (S3)
    - API (REST / GraphQL) [web:160][web:273]
- **Amazon Cognito**
  - User pools for sign-up/sign-in.
  - Provides JWT tokens used by Amplify to sign requests to S3/APIs. [web:261]
- **Amazon S3**
  - Stores uploaded photos in a dedicated bucket.
  - Access controlled via Cognito-authenticated IAM roles. [web:273]
- **AWS Lambda**
  - Node.js or Python functions:
    - Receives S3 key (photo location).
    - Calls Rekognition for faces/text.
    - Optionally writes metadata to DynamoDB/AppSync resolvers. [web:148]
- **Amazon Rekognition**
  - Face collections and search:
    - `CreateCollection`, `IndexFaces`, `SearchFacesByImage`. [web:67][web:22]
  - OCR/text detection:
    - `DetectText` to find text regions and content. [web:152][web:119]
- **AppSync + DynamoDB**
  - GraphQL API with `Photo` and `Person` models.
  - Automatically generated resolvers and queries via Amplify codegen. [web:273]

---

## 6. Implementation Roadmap

### 6.1 Current Phase (MVP – What to Implement Now)

**Goal:** Working pipeline from upload → analyze → view basic info.

1. **Backend Setup**
   - Configure Amplify project.
   - Add Auth (Cognito) + Storage (S3) + simple API (REST/Lambda).
   - Create Rekognition collection for faces. [web:67]

2. **Rekognition Lambda**
   - Implement Lambda with 3 actions:
     - `indexFace` → call `IndexFaces`.
     - `searchFace` → call `SearchFacesByImage`.
     - `detectText` → call `DetectText`. [web:67][web:152]

3. **Flutter App (MVP UI)**
   - Auth screen (basic sign-up/sign-in or even auto-sign-in for dev).
   - Single main screen with:
     - “Upload Photo” button.
     - Grid view of uploaded photos.
     - On tap → call backend to:
       - Show number of faces detected.
       - Show list of detected text lines.

4. **Metadata Storage (Initial)**
   - Minimal DynamoDB/AppSync schema for `Photo`:
     - `id`, `s3Key`, `detectedText`, `createdAt`.
   - Save metadata after analysis.

### 6.2 Future Phase (Full Project – Planned Implementation)

1. **Person Model & People Tab**
   - Add `Person` model with fields: `id`, `name`, `faceId`, `photoIds`.
   - Map Rekognition FaceIds to Person entities.
   - Implement People tab:
     - List of identified people.
     - Unidentified entries grouped by face similarity.

2. **Search Tab**
   - Implement GraphQL/API queries to:
     - Search by `detectedText` (contains query string).
     - Search by Person name (join Person ↔ Photo via face/IDs).

3. **Manual Identification & Grouping**
   - UI to select a face/person group and assign a human-readable name.
   - Merge persons when user confirms duplicates.

4. **UX Improvements**
   - Better error handling (network/offline).
   - Loading states & background uploads.
   - Image caching on device.

5. **Optional: Permissions & Sharing**
   - More advanced auth rules:
     - Per-user isolation of data (owner-based access).
   - Potential future: shared albums between users.

### 6.3 Technical Scalability (Backlog)

1. **Global Secondary Index (GSI) for Face Lookups**
   - **Problem**: Current `analyzePhoto` Lambda uses `ScanCommand` on `Person` table to find matching faces, which is O(N) complexity and inefficient at scale.
   - **Solution**: Implement a GSI on `faceId` for O(1) lookups.
   - **Implementation Plan**:
     1. Create `Face` model in `amplify/data/resource.ts`:
        ```typescript
        Face: a.model({
        	faceId: a.id().required(),
        	personId: a.id().required(),
        	s3Key: a.string().required(),
        }).secondaryIndexes((index) => [index('faceId')]);
        ```
     2. Update `analyzePhoto` Lambda to Query `Face` table first.
     3. Backfill existing data by iterating all Persons and creating Face records.
   - **Status**: Deferred for MVP (simplifying codebase).
