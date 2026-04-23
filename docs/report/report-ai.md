# PhotoSense: AI Based Photo Gallery for Face Clustering and Text Search

## Table of Contents

| Contents | Page No |
|---|---:|
| Project Title | 3 |
| Team / Group Formation | 3 |
| Technologies to be used | 3 |
| Tools | 3 |
| Problem Statement | 3 |
| Literature Survey | 4 |
| Project Description | 4 |
| Project Modules: Design/Algorithm | 4 |
| Implementation Methodology | 4 |
| Result & Conclusion | 4 |
| Future Scope and further enhancement of the Project | 4 |
| Advantages of this Project | 4 |
| Outcome | 5 |
| References | 5 |

## Project Title

**PhotoSense: AI Based Photo Gallery for Face Clustering and Text Search**

This title is selected because the project mainly focuses on smart image handling by using AI methods like face detection, face grouping, and OCR based text extraction. So, the title represents the actual aim of the work quite properly, and it also shows that the system is not just storing images but making them searchable and manageable in a better way [cite:2].

## Team / Group Formation

The team should not exceed 3 members, so a small group can manage this project without much confusion. For this project, the possible roles can be Developer, Tester, and Designer because the work includes backend development, checking of outputs, and also making the system easy to use.

| S. No | Student Name | Roll Number | System ID | Role |
|---:|---|---|---|---|
| 1 | __________________ | __________________ | __________________ | Developer |
| 2 | __________________ | __________________ | __________________ | Tester |
| 3 | __________________ | __________________ | __________________ | Designer |

## Technologies to be used

The project uses a backend centered architecture where Django is used as the web framework, and the system communicates through REST APIs with JWT based authentication. Amazon S3 is used for storing uploaded photos, AWS Rekognition is used for face detection, face search, and OCR text extraction, while SQLite or PostgreSQL can be used for database handling depending on development or production need [cite:2].

**Software Platform**
- Front-end: React frontend is planned in the project documents, but this branch context focuses on the backend presentation and backend APIs [cite:2][cite:3]
- Back-end: Django 4.2+
- Authentication: djangorestframework-simplejwt
- Database: SQLite / PostgreSQL
- Cloud Services: Amazon S3 and AWS Rekognition

**Hardware Platform**
- RAM: 8 GB minimum recommended
- Hard Disk: 20 GB free space or more
- OS: Windows, Linux, or macOS
- Editor: VS Code or any Python supported IDE
- Browser: Chrome, Edge, or Firefox

## Tools

Different tools are planned in this project for different phases of software development. Django is used for backend development, boto3 is used to connect with AWS services, Gunicorn is used for deployment runtime, and Render can be used as deployment platform for hosting the backend service [cite:2].

| Tool Name | Vendor Name | Version / Type | Purpose |
|---|---|---|---|
| Django | Django Software Foundation | 4.2+ | Backend web framework |
| boto3 | Amazon Web Services | Python SDK | Access S3 and Rekognition |
| Gunicorn | Gunicorn Developers | WSGI Server | Backend deployment server |
| PostgreSQL | PostgreSQL Global Dev Group | DBMS | Production database |
| SQLite | SQLite Consortium | Embedded DB | Development database |
| Render | Render | Cloud Platform | Hosting and deployment |
| GitHub | GitHub | Version Control Platform | Source code management and collaboration |

## Problem Statement

Nowadays people store many photos in phones and computers, but finding a particular image later becomes difficult because normal galleries mostly depend on manual folders or date sorting only. And for this, users cannot easily search photos by a person's face or by text written inside the image, which makes photo management slow and irritating in many situations [cite:2].

This project is selected because AI based image analysis can solve a practical daily problem. PhotoSense tries to solve this by uploading photos, analyzing them through Rekognition, extracting visible text, detecting faces, and then clustering similar faces into person groups so that users can name, merge, and search them later in a simple way [cite:2].

## Literature Survey

In recent years, many systems and research works have focused on image retrieval, face recognition, OCR, and cloud based media handling. Existing ideas usually combine computer vision with searchable media storage, and this project also follows a similar line, but it is more focused on a user level photo gallery workflow.

| Author / Source | Area | Methodology | Findings / Relevance |
|---|---|---|---|
| AWS Rekognition based system context | Face detection and clustering | Uses `index_faces`, `search_faces`, and `detect_text` APIs | Helps automate face grouping and OCR extraction in uploaded images [cite:2] |
| Django based REST backend design | Web service architecture | Plain Django views with JSON responses and JWT auth | Useful for creating a manageable and secure backend for gallery operations [cite:2] |
| Photo gallery search systems | Searchable image retrieval | Metadata and extracted text based filtering | Shows that text extraction can improve image searching in large collections [cite:2] |
| Cloud image storage platforms | Scalable media storage | Store images in object storage with generated URLs | Presigned URL approach supports safe image delivery without exposing direct storage access [cite:2] |

The survey shows that modern image systems often work better when AI and web backend are combined properly. So, this project stands on a useful combination of cloud vision, searchable metadata, and web APIs which can be used for a personal smart gallery type product [cite:2].

## Project Description

PhotoSense is an AI powered photo gallery system. The user uploads a photo, then the backend stores it in Amazon S3, sends the image data to AWS Rekognition for face indexing and text detection, and after that the system saves processed information like detected faces, detected text, face count, and clustered persons in the database [cite:2].

The project structure mainly contains Django backend files, models for `Photo`, `Person`, and `PhotoPerson`, helper files for machine learning and storage operations, and API views for upload, listing, searching, merge and delete actions. Instead of a very heavy architecture, the backend uses plain Django view classes and manual JSON handling, which keeps the implementation simple but still practical for project demonstration [cite:2].

**High Level Context Diagram**

User → React/Web Interface → Django Backend → Amazon S3 / AWS Rekognition → Database

This means the frontend sends requests, backend processes all logic, cloud services do storage and AI analysis, and final structured data is returned to the user interface [cite:2][cite:3].

## Project Modules: Design/Algorithm

The project is divided into some main modules. First is the authentication module where registration, login, and token refresh are handled using JWT. Then comes the photo module where image upload, listing, detail view, delete, and text search are provided. Another module is the persons module, which groups faces into person clusters and allows rename, detail view, delete, and merge operations [cite:2].

The main algorithm works during photo upload. When a user uploads a photo, the image is stored in S3, then Rekognition runs face indexing and text detection, after that for each detected face the system checks similar faces using `search_faces()`. If similarity is found, the face is added to an existing person cluster, otherwise a new unknown person is created. Finally, a linking record between photo and person is stored in the junction table [cite:2].

## Implementation Methodology

The implementation follows a backend API based methodology. First, the system takes image input from user side, then the Django backend reads the image bytes, uploads them to S3, performs Rekognition analysis, stores metadata in the database, and returns the structured response with presigned URLs and analysis details [cite:2].

For data modeling, the project has `Photo`, `Person`, and `PhotoPerson` entities where `Photo` and `Person` are connected through a many to many style junction table. The information flow is like this: upload request comes in, AI services analyze content, metadata gets stored, then later list, detail, search, rename, merge and delete APIs use the same stored data to serve the user [cite:2].

Testing can be done by checking API responses for all major endpoints like register, login, upload, search, list persons, merge persons, and delete photo. And for this, a defect log can be maintained manually during testing by recording bug description, module affected, expected output, actual output, and fixing status.

## Result & Conclusion

The expected result of this project is a smart photo management system where a user can upload photos and automatically get face detection, face grouping, and text extraction features. This reduces manual work and gives a more intelligent way to search and organize image collections, which is much better than a simple gallery sorted only by date [cite:2].

So, the project is innovative in a practical sense because it combines cloud AI services with a custom backend workflow. Main achievements include automatic clustering of persons, searchable OCR based photo lookup, and secure cloud based image handling using presigned URLs, which makes the system useful and also good enough for academic demonstration [cite:2].

## Future Scope and further enhancement of the Project

The project can be improved in many ways in future. A stronger frontend can be integrated fully, pagination can be added for large collections, duplicate clustering errors can be reduced, password validation can be improved, and asynchronous upload processing can be introduced so that the user does not wait during long AI analysis [cite:2][cite:3].

Also, advanced enhancements can include emotion recognition, location wise image grouping, better search filters, album generation, and mobile plus web synchronization. In future maybe the system can even support recommendation style memory collections or event wise grouping too.

## Advantages of this Project

This project has many advantages for users who manage large collections of images. It helps in fast searching using detected text, gives face based grouping automatically, reduces manual effort of sorting photos, and stores media in a scalable cloud environment rather than only keeping it locally [cite:2].

The audience who can benefit from this project includes students, researchers, photographers, families, and general users who want a smarter gallery. For institutions too, this kind of project gives a good example of how AI, cloud services, and backend engineering can be combined into one useful application [cite:2].

## Outcome

The possible outcome of this project is **Project to Product** because the problem being solved is practical and can be extended to a usable smart gallery platform. It also has scope for **Research Oriented** work because improvements in clustering accuracy, search behavior, and OCR quality can be studied and written as research papers or technical publications.

This project may also be presented in hackathons or technical competitions because it has a visible AI based use case and clear demonstration flow. So in an academic setting, the outcome is not limited to marks only, it can go further if developed in a better and complete manner.

## References

1. PhotoSense project repository docs directory: [https://github.com/sudols/photo-sense/tree/backend-presentation/docs](https://github.com/sudols/photo-sense/tree/backend-presentation/docs) [cite:1]
2. REACT_FRONTEND_CONTEXT.md, PhotoSense backend architecture and workflow details [cite:2]
3. REACT_FRONTEND_IMPLEMENTATION_PLAN.md, project structure and implementation planning [cite:3]
4. AWS Rekognition Documentation: [https://docs.aws.amazon.com/rekognition/](https://docs.aws.amazon.com/rekognition/)
5. Django Documentation: [https://docs.djangoproject.com/](https://docs.djangoproject.com/)


**Signed By: Faculty**
