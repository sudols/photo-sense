make this sound like a fast human draft

THE PROBLEM THAT STARTED IT ALL

All of us have hundreds of photos on our phones. Trying to find a specific photo, say, all photos of your friend from last semester, or one photo of a whiteboard from a lecture, usually involves a lot of scrolling. Google Photos and similar apps have solved this problem, but they create vendor lock in problems and privacy issues, as well as lack of transparency in processing pipelines, and provide platform-dependent features and functionality you cannot control.

I imagined doing something different. Building an intelligent gallery that I can control, and where I can explain and have control over all aspects of face recognition and text recognition pipelines. This led to the development of PhotoSense, an intelligent cross-platform gallery application that features automated facial recognition, face clustering, and text extraction.

This blog focuses on the problems I had to solve and the decisions I took in designing the system.

For the Frontend, I used the Flutter framework version 3.x, with Material 3 design, so I can build the Frontend targeting Android, Web, and Linux from a single codebase.

For the Backend, I decided to use the Django REST framework with the SimpleJWT library to provide a clean REST API, and manage authentication and authorization using JWTs.

For the AI and ML, I used Amazon Rekognition to perform facial recognition, facial indexing, facial similarity search, and OCR. I configured the SDK to send requests synchronously, from Django to the AWS backend via the Boto3 library from the Django upload view.

PhotoSense's most defining feature is the immediate processing of your photo after upload. A single POST /api/photos/upload/ invokes the entire ML pipeline -- all at the same time, and all in the same HTTP request. Here's what happens:

Step 1: Read into Memory

The uploaded file is read into a single in-memory byte buffer. This buffer is then sent to three different consumers: S3 and two Rekognition services, IndexFaces and DetectText. This is a design choice -- Rekognition services rely on S3 to read. Instead, Rekognition will receive the Image={“Bytes”: image_bytes} directly from the Django memory. This is how the issue of S3 read permissions is circumvented and the potential failure points are minimized.

Step 2: Upload to S3

The raw image bytes are uploaded to S3 at a predetermined path: photos/{user_id}/{uuid}.{ext}. This is simply storage -- S3's job is done.

Step 3: Face Detection + Indexing

The image bytes are sent to Rekognition's IndexFaces API via index_faces(). This happens:

1. All faces in the image are detected, and bounding boxes and confidence scores are returned.

2. Each detected face is indexed into a Rekognition collection (photosense-faces) and a unique, search-capable FaceId vector is created.

This dual purpose is essential, as it allows every face that enters the system to be searchable for future similarity matching.

Step 4: Text Retrieval Using OCR

The method detect_text() invokes the DetectText function from the Rekognition API. I filter out the results to include only LINE-type detections with confidence levels greater than 80%, as excluding individual word detections yields results that are more desirable. Thus, if you take a picture of a whiteboard, a poster, or a document, PhotoSense will capture the text and allow you to search it.

Step 5: Face Clustering (The Most Challenging Part)

It gets even more intriguing here. For every face that has been detected in the image:

1. Look for matches: Execute search_faces(face_id) against the Rekognition collection with a similarity threshold of 90%. This will scan the indexed face vectors, not the actual images.

In the event of a match: Retrieve the Person record from the database whose face_ids JSON array contains the matched face_id, and add the new face_id to that person's collection.

If there is no match: A new Person record will be created with name = "Unknown Person" and is_unnamed=True. This record can be renamed by the user later.

Associate the face with the image: A PhotoPerson junction record will be created, with a unique_together constraint to avoid duplicates.

The 90% threshold is a purposeful design choice. If it's set too low, dissimilar individuals may get merged together. If set too high, an identical individual may get split into multiple entries across varying lighting or angles. When clustering does make a mistake, users can manually merge individuals in the UI.

The Core Structure

A total of three tables are used for overall functionality:

The Photo table contains image metadata, as well as ML outcomes, which include lists of face_ids, detected_text strings, and detected_faces, each of which is an object that encompasses a face ID, a set of bounding box coordinates, and a confidence score. These outcomes are stored as JSONField, which have the same functionality in both SQLite and PostgreSQL.

Person is used to represent a facial cluster. Person contains a primary face_id, a list of face_ids that is bound to grow as more photos of the same person are uploaded, bounding box coordinates used for avatar rendering, and finally a thumbnail_s3_key that is a pointer to the first photo in which this person was captured.

PhotoPerson is the many to many junction table with a unique_together constraint. A person can exist in several photos, and a photo can contain several persons.

User --1:N--> Photo

User --1:N--> Person

Photo --M:N--> Person (via PhotoPerson)

_Data isolation_ All queries are owner scoped (Photo.objects.filter(owner=request.user)). Per User data isolation is thus enforced.

The Face Avatar Problem

One of the more challenging but satisfying tasks was rendering face avatars. Rekognition detects faces and provides bounding boxes as normalized coordinates (0.0 to 1.0) based on the image's dimensions. The challenge was to figure out how to crop and zoom into a specific face from the full image using only the default image widgets that Flutter provides.

Having gone through multiple failed attempts, including FittedBox, OverflowBox, and custom clippers, I finally came up with a working solution using Transform.scale inside the loadingBuilder callback:

To convert the bounding box to Flutter's Alignment coordinate space (-1.0 to 1.0):

centerX = (left + width/2) \* 2 - 1

centerY = (top + height/2) \* 2 - 1

Then, render the image with BoxFit.cover.

Next, for the zoom transform, do the following: Transform.scale (scale: 1 / max(bw, bh))).

If the bounding box of the face covers 10% of the image width, the scaling factor becomes 10. Hence, face zooming is very aggressive. The circular Container clips it into a clean avatar. Thus, this approach needs no server-side thumbnail generation - the full photo is downloaded and cropped purely on the client.

The Flutter Frontend

The frontend uses a purposely simplistic architecture: static service classes (ApiClient, AuthService, PhotoService, PersonService) that wrap HTTP calls, simple Dart model classes that include fromJson factories, and state management via setState. There is no usage of Riverpod, Bloc, or Provider. For six screens and an easily understandable data flow, setState is enough and maintains the readability of the code.

Home/Gallery: Photos are organized and shown in a 3-column grid and grouped by date with sticky headers ("Today", "Yesterday", "March 1, 2026"). Uses flutter_sticky_header for this scroll effect, and there's a SpeedDial FAB for single and batch upload.

Photo Detail: The complete image is shown and detected faces are illustrated as circular avatars (using the cropping technique detailed above). If the face is unnamed, a tap will open a dialog to name them. Cards with metadata will show face count, detected text, and time stamps.

People: There are two sections in the People view. The first is horizontally scrollable "Who's this?" for unnamed faces (with a blue + badge), and the second is a vertical grid for named faces. This UX pattern effectively encourages face identification.

Search: A standard Material 3 SearchBar that queries GET /api/photos/search/?q=text. Matching is done at the server, and rendering is done at the client.

JWT Auth Flow:

When a user logs in, the server issues an access token with a 1-day lifetime and a refresh token with a 30-day lifetime. These tokens are saved in Flutter Secure Storage, which is backed by the Android Keystore. Each API call uses the access token as a Bearer token in the request headers. In Main.dart, a global 401 interceptor is set up to catch expired access tokens. The interceptor automatically sends the user to the sign-in screen, which prevents the user from seeing a broken screen.

Security Considerations

Here are a few important decisions made regarding security:

Presigned URLs: S3 does not allow public access to photos. For API responses, the photos are made accessible via presigned URLs, created by the server, with a 7-day expiry. Non of the S3 photo keys are accessible by the Flutter clients.

Owner-scoped queries: For every Django queryset, there is always the filter owner=request.user. There is no endpoint where User A can access the photos, people, or links of User B.

Token storage: JWT tokens are stored in Flutter Secure Storage, which is based on the Android Keystore on Android. Tokens are not stored in SharedPreferences or plaintext files.

In-memory image processing: The image bytes to be processed by Rekognition are sent directly from Django's memory and not by S3 referencing. This means that S3 permissions and Rekognition permissions are independent resulting in a cleaner security boundary.

What I Learned

The right level of abstraction is really important. Moving from five Amplify services to a single Django server didn't just make the codebase simpler -- it made every single bug debuggable. If face clustering results in the wrong output, I can go into Django Admin, look at the Person records, see the list of face IDs, and understand what went wrong. On the other hand, with Lambda + DynamoDB, that same investigation would have needed me to scour multiple services in CloudWatch logs.

Synchronous can be good here too. For scenarios like people uploading a few photos, making a request synchronous for a few seconds is a much simpler approach, and avoids a ton of eventual consistency problems.

Face clustering is a solved problem, until it isn’t. For many use cases, Rekognition’s face matching with manual face pairings is great, and 90% coverage is fine. However, for the same person, multiple clusters can be created due to different lighting, aging, or extreme angles. The ability to manually cluster faces is not a luxury; it is a requirement for the product to be any good.

There is an underappreciated value to client-side manipulation of images. The avatar face cropping feature was a highlight of the project for me. Rekognition gives you a bounding box for each face, and transforming the box based on those coordinates to scale in Flutter with the right pivot was a delightful challenge. It required no server-side thumbnail generation, no image processing libraries, just pure math and widgets.

Every migration has "why was this done this way" conversations, but with more design opportunity. Moving from Amplify to Django was not simply a port, it was correcting architectural flaws: client-side search became server-side, triple-step uploads became single-call, double-encoded JSON became native. Every migration provides a design opportunity.

In considering what building an AI-powered gallery from the ground up entails, PhotoSense, rather than competing with Google Photos, aims to understand: the face clustering pipeline, the pros and cons of synchronous vs. asynchronous processing, the data modeling of many-to-many face-photos, and the client-side rendering techniques to facilitate face avatars without requiring a server-side image processor.

The complete source code encompasses the Django backend and Flutter frontend, as well as the documentation on architecture, data models, API endpoints, and migration history. I trust this walkthrough will benefit anyone with an interest in developing a similar project, particularly with regard to face clustering and the methodologies involved.
