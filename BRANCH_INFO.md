# Backend Presentation Branch

This branch (`backend-presentation`) contains **backend code only** - all Flutter references and frontend code have been removed for a clean backend-focused presentation.

## What Changed from Main Branch

### ❌ Removed
- **All Flutter code**: `lib/`, `android/`, `ios/`, `web/`, `linux/`, `test/`
- **Flutter config**: `pubspec.yaml`, `analysis_options.yaml`, `package.json`
- **Flutter docs**: `FLUTTER_FRONTEND.md`, `blog.md`, `roadmap.md`
- **Flutter mockups**: `docs/flutter-mockup/`
- **IDE configs**: `.vscode/`, `.idea/`, `.ruff_cache/`

### ✅ Updated
- **UML diagrams**: Replaced "Flutter App" → "Client" 
- **Documentation**: Replaced "Flutter App" → "Client" or "Mobile/Web Client"
- **README.md**: Complete rewrite for backend showcase
- **.gitignore**: Python/Django focused

### 📁 New Structure
```
photo_sense/
├── backend/              # Django application (unchanged)
├── docs/
│   └── uml/             # System diagrams (updated, no Flutter refs)
├── presentation/         # All presentation docs in one place
│   ├── BACKEND_WALKTHROUGH.md
│   ├── AUTH_AND_DATABASE_DEEP_DIVE.md
│   ├── AUTH_DB_VISUAL_DIAGRAMS.md
│   ├── AUTH_DB_PRESENTATION_CHEAT_SHEET.md
│   ├── PRESENTATION_QUICK_REF.md
│   └── UPLOAD_FLOW_DIAGRAM.md
├── .gitignore           # Backend-only
└── README.md            # Backend showcase README
```

## How to Use

### For Presentation
1. **Start here**: Read `README.md` for overview
2. **Deep dive**: `presentation/BACKEND_WALKTHROUGH.md`
3. **Auth & DB**: `presentation/AUTH_AND_DATABASE_DEEP_DIVE.md`
4. **Quick ref**: `presentation/PRESENTATION_QUICK_REF.md`

### Switch Between Branches
```bash
# Backend-only presentation (current)
git checkout backend-presentation

# Full project with Flutter
git checkout main
```

## Key Points for Professor

✅ **No Flutter references** - All diagrams and docs use generic "Client"  
✅ **Backend focused** - Django, JWT, PostgreSQL, AWS  
✅ **Clean structure** - Easy to navigate  
✅ **Comprehensive docs** - 6 presentation guides  
✅ **UML diagrams** - System architecture, sequence, ER diagrams  

## Backend Code Structure

The `backend/` directory contains:
- **13 API endpoints** (3 auth + 5 photo + 5 person)
- **4 database models** (User, Photo, Person, PhotoPerson)
- **JWT authentication** (1-day access, 30-day refresh)
- **AWS integration** (S3 storage + Rekognition ML)
- **Face clustering** (automatic person grouping)

---

**Created**: March 18, 2026  
**Purpose**: Backend-only presentation for non-Flutter specialist professor  
**Parent Branch**: `main` (contains full Flutter + backend project)
