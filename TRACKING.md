# PhotoSense Project Tracking

This file tracks the implementation progress of the PhotoSense application.

## 🚀 Project Status Overview

- **Current Phase**: MVP (Minimum Viable Product)
- **Status**: Core pipeline (Upload -> Analyze -> Persist -> Display) is **IMPLEMENTED**.
- **Next Focus**: People Management and Advanced Search.

---

## ✅ Implemented Features

### Backend (AWS Amplify)

- [x] **Auth**: Cognito User Pools configured and integrated.
- [x] **Storage**: S3 bucket configured for photo storage with identity-based paths (`photos/{identityId}/...`).
- [x] **Database**: AppSync + DynamoDB schemas defined for `Photo`, `Person`, `PhotoPerson`.
- [x] **Analysis Pipeline**:
  - [x] Lambda function `analyzePhoto` triggered on S3 upload.
  - [x] **Face Indexing**: Calls Rekognition `IndexFaces` to store face vectors.
  - [x] **Text Detection**: Calls Rekognition `DetectText` to extract lines of text.
  - [x] **Metadata persistence**: Updates `Photo` record in DynamoDB with `faceIds`, `facesCount`, `detectedText`.

### Frontend (Flutter)

- [x] **Authentication**: Sign Up / Sign In / Sign Out screens.
- [x] **Home Screen**:
  - [x] Grid view of uploaded photos.
  - [x] Photo upload functionality (Gallery picker).
  - [x] Real-time updates (auto-refresh on upload/delete).
- [x] **Photo Details**:
  - [x] View full-screen image.
  - [x] Display analysis results: "Faces Detected" count, "Detected Text".
  - [x] Delete photo (removes from S3 and DynamoDB).

---

## 📋 Backlog & Remaining Features

### 1. People Management (Priority: High)

_Goal: Group faces into named identities._

- [ ] **Backend - Person Logic**:
  - [ ] Create a mechanism to associate a `faceId` with a `Person` entity.
  - [ ] Implement strict face matching to group similar `faceIds` under one `Person`.
- [ ] **UI - People Tab**:
  - [ ] Create `PeopleScreen` tab in the main navigation.
  - [ ] Display list of identified people (thumbnails + names).
  - [ ] Display "Unidentified" group for faces without names.
- [ ] **UI - Tagging Flow**:
  - [ ] Allow user to tap a face (or face bounding box) on `PhotoDetailScreen`.
  - [ ] detailed view to assign a name to a face (creates/links `Person`).

### 2. Search & Discovery (Priority: Medium)

_Goal: Find photos by content._

- [ ] **UI - Search Screen**:
  - [ ] Create `SearchScreen` tab.
  - [ ] Search bar for text input.
- [ ] **Search Logic**:
  - [ ] Implement AppSync queries to filter Photos by `detectedText` (contains).
  - [ ] Implement search by Person Name (requires `Photo` <-> `Person` link).

### 3. Advanced UI/UX (Priority: Low)

- [ ] **Bounding Boxes**: Draw boxes around faces and text in `PhotoDetailScreen` (requires storing bounding box data in `Photo` model).
- [ ] **Infinite Scroll**: Optimize `HomeScreen` for large libraries (currently fetches all).
- [ ] **Albums/Folders**: Logical grouping of photos.

---

## 🛠 Technical Debt & Improvements

- **Lambda Config**: `COLLECTION_ID` is hardcoded/env-var based. Ensure collection creation is robust (currently `ensureCollection` checks existence).
- **Error Handling**: Enhance UI feedback for network errors during analysis.
- **Bounding Box Storage**: Currently only `faceIds` are stored. To draw boxes on UI, we need to store `BoundingBox` geometry from Rekognition in the `Photo` model.
