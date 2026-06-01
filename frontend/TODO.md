# Frontend TODOs: Abuse Prevention & Rate Limiting

The backend currently enforces the following rules in `PhotoUploadView`:
1. **File Size Limit:** 5MB maximum per photo. (Returns `400 Bad Request`)
2. **Quota Limit:** Maximum of 30 photos per portfolio account. (Returns `403 Forbidden`)

Currently, the frontend (specifically `src/pages/HomePage.tsx`) catches all upload errors and displays a generic *"Upload failed. Please try again."* message.

## Required Updates

- [ ] **Display Backend Error Messages:** Update the `catch (error)` block in the `handleUpload` function inside `HomePage.tsx` to read the specific error message sent by Django (e.g., via `error.response?.data?.error`). This ensures users see the exact quota or size limit reason instead of a generic failure.
- [ ] **Client-Side File Size Pre-validation:** Check the file size *before* making the HTTP request to the backend. If `file.size > 5 * 1024 * 1024`, immediately reject the upload on the client side with an error message to save bandwidth and backend processing.
- [ ] **Proactive Quota Enforcement (Optional but recommended):** Disable the "Upload Photo" button entirely if `photos.length >= 30` to proactively prevent the user from attempting to upload more photos once their quota is filled.
