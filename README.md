# StudyMate

A study companion app for Bangladeshi students: routines, Pomodoro, notes, flashcards, MCQ practice, Islamic life, social study groups.
Built with Flutter + Firebase (Auth, Firestore, Storage, FCM). Targets: **Android** (main), web, iOS (planned).

## Folder layout

```
StudyMate App/
├── studymate/              ← this repo (all code)
│   ├── lib/                app code
│   │   ├── tools/          one file per tool screen
│   │   ├── mcq/            MCQ practice, PDF import, mistake book
│   │   └── widgets/        shared widgets (empty state, skeleton, avatar …)
│   ├── assets/             audio, data (MCQ bank …), images, fonts
│   ├── test/               unit tests  →  flutter test
│   ├── docs/               Firebase rules / index notes to paste in the console
│   ├── packages/           vendored plugin (flutter_tesseract_ocr)
│   ├── android/  ios/  web/
│   ├── CLAUDE.md           detailed change log + notes for Claude Code
│   └── pubspec.yaml        version + dependencies
└── releases/               built APKs to share (not in git)
```

## Daily work

```bash
flutter pub get
flutter devices
flutter run -d <phone id>
flutter analyze
flutter test
```

## Making a release APK

1. Bump `version:` in `pubspec.yaml` (e.g. `1.0.9+10` → `1.0.10+11`). The in-app update popup compares this.
2. `flutter build apk --release`
3. Copy `build/app/outputs/flutter-apk/app-release.apk` to `../releases/StudyMate-<version>.apk`.

Release signing uses `android/key.properties` + `android/studymate-release.jks`.
**These two files are not in git. Keep a backup (Google Drive / pen drive).** Without them you cannot publish updates for the same install.

## Git workflow

- `main` = the current working app.
- New work: `git checkout -b feature/<name>` → commit → merge into `main` when tested on the phone.

## Firebase console (manual steps)

- Firestore rules: `docs/firestore-rules-additions.md`
- Storage rules: `docs/storage-rules.md`
- Leaderboard index: `docs/firestore-index-leaderboard.md`
- Release key SHA-1 must be added under Project settings → Android app (for Google Sign-In).
