# StudyMate — project notes for Claude Code

## About the owner
- Owner: Abu Musa (GitHub: s-14-2019913546-labMusa). Reply in **Bangla (বাংলা)**, plain and practical.
- He built the app himself (previously with Antigravity) and wants it smoother and more user-friendly.
- Test device: **MEIZU Lucky 08 (Android 14)** connected by USB. Usual workflow: make changes → `flutter run` on the phone → he checks it on the phone.
- Package name: `com.abumusa.studymate`. Firebase project backs auth, Firestore, Storage, FCM.

## How to work here
1. After code changes, run on the phone: `flutter devices` → `flutter run -d <MEIZU id>` (or `flutter build apk --release` for an APK).
2. Bump `version:` in `pubspec.yaml` for every APK he will share — the in-app update popup (`lib/update_service.dart`) compares versions.
3. Commit to a feature branch, not `main`, unless he says otherwise. End commit messages with the attribution lines Claude Code normally adds.
4. Bengali text: keep files UTF-8. A build installed in Nov 2026 showed garbled Bengali (mojibake) on the Tools page ("Next-day Routine (...)") even though GitHub's source is clean — his local copy may have had encoding damage. Never re-save files in another encoding.

## App map (where things live)
- Entry: `lib/main.dart` → `splash_screen.dart` (monthly password check, app lock) → `auth_screen.dart` → `focus_mode_screen.dart` → `dashboard_screen.dart`.
- Bottom tabs: Home (`dashboard_screen.dart`), Tools (`tools_screen.dart`, ~11,800 lines, holds many tool screens), Profile (`profile_screen.dart`).
- Tools: AI Study Planner, Next-day/Weekly routine, Calculator, Pomodoro (forest), Stopwatch, Notes (QuickNotes + NoteDetail), PDF Reader, Daily Diary, 1-4-7 Revision, Flashcards, Task History, Daily News, Dictionary, Study Map, Countdown, Calendar, My Study Sheets (Google Sheets → routine), Islamic Life, Breathing, Focus Music, Social Hub (chat, leaderboard, friends, groups), Study Room, Partner Tasks, Web Study, Study Analytics, Notifications, Mood, Sleep, Theme.
- StudyMate Bot (offline, slash commands): `bot_chat_screen.dart`.
- AI: `ai_service.dart` (Gemini via `google_generative_ai`; key stored in `users/{uid}.geminiApiKey`).
- XP/levels/badges/streak: `gamification_service.dart`.
- Backup: `cloud_sync_service.dart`. Google Sheet import: `google_sheet_routine_service.dart`, `multi_sheet_manager_screen.dart`.

## Done on branch `fix/audit-issues-nov2026` (12 Nov 2026, from a full audit)
- Leaderboard read `xp` but XP is saved as `totalXP`; streak was never saved; weekly XP never written → everyone showed 0. Fixed (streak saved via `GamificationService.saveStreak`, weekly XP with Saturday week start).
- Gemini models `gemini-1.5-flash` / `gemini-pro` are shut down → AI always silently fell back to offline. Now tries `gemini-flash-latest`, `gemini-3.5-flash`, `gemini-3.1-flash-lite`, `gemini-2.5-flash`. Added Profile → "AI Settings (Gemini API Key)" with a Test button.
- Notes "Generate AI Quiz" was fake (just a snackbar) → now builds a flashcard deck from the note (offline fallback) and opens it.
- Notes "Version History" was fake (hard-coded times, "(Simulation)") → real versions in `notes/{id}/versions` (last 10), Restore works.
- Focus Music labels didn't match (all were SoundHelix demo songs) → bundled looping offline sounds in `assets/audio/focus_*.ogg` (lo-fi, rain, forest, brown noise).
- Google Sheet re-sync duplicated tasks; Replace mode deleted manual tasks → dedupe by title+topic+start time; Replace only removes `gsheet_` tasks. Bot `/revision` de-duplicated.
- Pomodoro tree died when the screen auto-locked → screen kept on during Focus via MethodChannel `studymate/screen` in `MainActivity.kt`.
- Backup missed many collections and broke above 500 docs → more collections + sub-collections, chunked batches.
- About Us showed hard-coded 1.0.0 → reads `package_info_plus`. Version bumped to `1.0.6+7`.
- Dictionary pronunciation now uses `flutter_tts`. Release signing uses `android/key.properties` if present, else debug key.
- NOT yet compiled — first job is `flutter pub get` + `flutter run`, then fix any build errors.

## Open questions / still to do
- Firestore rules: confirm writes are allowed for `users/{uid}` fields `streak`, `weeklyXp`, `weeklyXpWeek` and `users/{uid}/notes/{id}/versions`.
- Firebase Storage (chat/notes images, cloud backup) needs the Blaze plan for `*.firebasestorage.app` buckets — ask him whether the project is on Blaze.
- Profile photo is stored only on the device (friends can't see it).
- Release keystore: he has none yet; changing the signing key forces users to reinstall once.

## UX improvement ideas he asked for (not started — ask which to do first)
Quick wins: search + pinned/recent tools on the Tools page; auto-skip or optional Focus Mode screen; one-tap "add today's weekly routine" in the Home empty state; consistent single language (no mixed English/Bangla labels); Undo after delete.
Daily use: one-line quick add ("বাংলা ব্যাকরণ ৮টা–১০টা"); Start/Complete buttons inside notifications; Android home-screen widget (next task, streak, next prayer); nightly summary notification; remove duplicate entry points (Calendar, Notifications, chat) and consider a 4th bottom tab.
New users: short onboarding with exam choice (BCS/Bank/Primary) to preload syllabus; helpful empty states; clear "add Gemini key for better AI" prompt; monthly password check off by default.
Look & feel: in-app text size, Bengali-friendly font (Hind Siliguri / Noto Sans Bengali), bigger tap targets, skeleton loaders.
Code health: split `tools_screen.dart` into separate files; cache Firestore data for faster screens.
