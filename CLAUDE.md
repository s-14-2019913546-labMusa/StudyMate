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
- Entry: `lib/main.dart` → `splash_screen.dart` (monthly password check, app lock) → login → `app_entry.dart` decides: onboarding (new accounts only) → `focus_mode_screen.dart` (auto/manual/off) → `dashboard_screen.dart`.
- Bottom tabs: Home (`dashboard_screen.dart`), Tools (`tools_screen.dart`, ~600 lines; tool screens live in `lib/tools/*.dart`), Profile (`profile_screen.dart`).
- Strings: use `'Key'.tr()` with entries in `language_manager.dart`, or `trx('English', 'বাংলা')` for new text. Don't import `easy_localization` in a file that also imports `language_manager.dart` (both define `.tr()` → compile error).
- Checking errors: `flutter analyze` prints `error - ...` (not `error •`). Don't run two flutter commands at once (engine.realm lock crash).
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
- Compiled and run on the MEIZU on 12 Nov 2026. Merged `main` (tools split + UTF-8 fixes) into this branch; the audit fixes were re-applied to `lib/tools/quick_notes_screen.dart` and `pomodoro_timer_screen.dart`.

## UX batch (12 Nov 2026, version 1.0.7+8)
- Tools page: search, "Recently used" row, long-press a tool to pin ⭐ (SharedPreferences `tools_pinned_v1`/`tools_recent_v1`). Calendar and Notifications removed from Tools (Home has them).
- Focus Mode: auto-continues after 3 s; Profile → "Focus screen at startup" (auto/manual/off).
- Undo snackbar after deleting today's task, weekly task, note, flashcard deck (`widgets/undo_snackbar.dart`).
- Quick add: long-press "New Task" → one line, parsed by `quick_add_task.dart` (tests in `test/quick_task_parser_test.dart`). Home empty state has Quick add / Weekly routine buttons.
- Notifications: task start has ▶ Start, end warning has ✓ Complete (`task_notification_actions.dart`, needs `ActionBroadcastReceiver` in the manifest). Completing from a notification does not award XP yet.
- Nightly summary (`nightly_summary_service.dart`, default 21:30, Profile → Nightly summary). Rescheduled with current numbers whenever today's tasks change; "Plan tomorrow" opens the next-day routine form.
- Home-screen widget (`home_widget` package): `StudyWidgetProvider.kt`, `res/layout/study_widget.xml`, data from `home_widget_service.dart` (next task, streak, progress, next prayer from the prayer cache file).
- Onboarding (`onboarding_screen.dart`, `exam_presets.dart`): shown after sign-up only; Profile → "App intro & exam syllabus" for existing users. BCS/Bank/Primary presets add a Study Map folder + optional Sat–Thu routine.
- Profile → "Text size & font": in-app text scale, Hind Siliguri / Noto Sans Bengali, Bengali font as main font in Bengali.
- Guided empty states (`widgets/empty_state.dart`) for Flashcards, Study Map, Countdown; skeleton loaders (`widgets/skeleton.dart`) on Home, Notes, Weekly, Task History, Flashcards, Study Map, Countdown.
- Task card buttons 46dp tall, header icons have bigger tap areas.
- ~170 snackbar/error messages now follow the chosen language.
- Firestore offline persistence was already on (`main.dart`); task cards now share one cached folder list instead of one read per card.

## Open questions / still to do
- Firestore rules: confirm writes are allowed for `users/{uid}` fields `streak`, `weeklyXp`, `weeklyXpWeek` and `users/{uid}/notes/{id}/versions`.
- Firebase Storage (chat/notes images, cloud backup) needs the Blaze plan for `*.firebasestorage.app` buckets — ask him whether the project is on Blaze.
- Profile photo is stored only on the device (friends can't see it).
- Release keystore: he has none yet; changing the signing key forces users to reinstall once.

## Study features (12 Nov 2026, same branch)
- MCQ practice & model test: `lib/mcq/` (service, test, result, home + import sheet, mistake book). Starter bank `assets/data/mcq_bank.json` (80 Qs, 8 subjects, tagged by exam). Users add Qs by paste (ক/খ/গ/ঘ + "উত্তর: খ") or AI (`AIService.generateMcqs`); stored in `users/{uid}/mcq_questions`. Results in `mcq_results` → weak subjects.
- Mistake Book: `users/{uid}/mistakes`, 1-4-7 schedule, mastered after 3 correct reviews; wrong answers also go to the "ভুল প্রশ্ন (MCQ)" flashcard deck.
- Today's Revision (`daily_review_screen.dart`): due flashcards across all decks (existing per-card SRS) + due mistakes; Home card shows the count. `FlashcardStudyScreen` reads `card['_deckId']` for mixed decks.
- Photo to Note (`photo_to_note_screen.dart`): Gemini vision OCR (`AIService.extractTextFromImage`, needs the user's Gemini key) → note / MCQ / flashcards.
- Study Map pacing: folder field `examDate`; header shows days left, topics/day (keeps ~10% days for revision) and the 3 subjects furthest behind.
- Tests: `test/mcq_test.dart` (bank validity, paste parser).

## Habit & social features (12 Nov 2026, same branch)
- Owner rule: **nothing that costs money**. OCR is on-device Tesseract (`offline_ocr_service.dart`, vendored plugin in `packages/flutter_tesseract_ocr` because the pub version uses `jcenter()`); Bengali/English traineddata downloads once from the official tessdata_fast repo. Gemini stays optional (user's own free key) and every call has a timeout.
- Firestore rules must be updated by hand in the console: see `docs/firestore-rules-additions.md` (mistakes, mcq_*, forum_posts were PERMISSION_DENIED).
- `study_habits_service.dart`: daily goal (+20 XP), study minutes (tasks + Pomodoro trees), streak day-off (2/month, used in `GamificationService.calculateStreak`), 9 PM reminder, distraction count, weekly minutes (`users/{uid}.weeklyStudyMinutes/weeklyStudyWeek`), Friday 8 PM weekly report notification.
- `weekly_report_screen.dart`, `focus_hub_screen.dart` (4th tab "Focus"), `dnd_service.dart` + MethodChannel `studymate/dnd` in `MainActivity.kt`.
- Pomodoro: 10 s grace + warning notification when leaving the app; auto DND option.
- Voice task add: mic in quick add (`speech_to_text`, phone's own recognizer); parser understands কাল/পরশু/tomorrow, Bengali number words, সাড়ে, আধা/দেড়/আড়াই ঘণ্টা; future-day tasks go to that day's routine.
- Phone file backup/restore in Cloud Backup screen (save/share JSON, restore from file).
- Group weekly challenge + leaderboard (`group_challenge_card.dart`, `chats/{id}.weeklyGoalMinutes`), live group Pomodoro in Study Room (`tools/live_room_timer.dart`, `study_rooms/{code}.liveTimer`), Q&A forum (`forum_screen.dart`, `forum_posts`).

## Still open from the UX list
- 4th bottom tab (Chat or Focus) — not added; screens there have their own Scaffold/back button, needs care.
- Language: many plain labels (not snackbars) are still English-only or Bengali-only; continue with `trx()` screen by screen.
- Nightly summary is computed when the app last updated it; if the app is not opened for a day the numbers can be stale.

## PDF → MCQ import (13 Nov 2026, version 1.0.8+9)
- MCQ Practice → "প্রশ্ন যোগ" sheet → "PDF থেকে প্রশ্ন যোগ করুন" opens `lib/mcq/pdf_import_screen.dart` (pick PDF → page range + subject → read → review list → save).
- `pdf_text_service.dart`: pdfrx (PDFium, native assets) text per page; pages with <40 real chars (scanned/CamScanner) are rendered at ~200 dpi grey PNG and read by `OfflineOcrService` (Tesseract). Option "read every page as OCR". No page limit, one page at a time, Stop button keeps what was read.
- `pdf_mcq_parser.dart`: numbered questions (১। / 1. / Q1.), inline options split ("ক) .. খ) .." / "(ক)" / "a." / "গ. ৭ ঘ. ৯"), inline "উত্তর:"/"Ans:" (letter or option text), `*`/✓ marks, ব্যাখ্যা lines, answer-key lines ("১.ক ২.খ", "1-a, 2-c") matched by question number. Falls back to `McqService.parsePasted` if nothing found.
- `bijoy_converter.dart`: SutonnyMJ/Bijoy → Unicode (auto-detected, toggle in review) and fixes visual-order kars (ি/ে/ৈ before the consonant) in Unicode PDFs.
- `McqService.saveCustom` now commits in chunks of 400 (Firestore 500 limit). Saved questions have `source: 'pdf'`.
- Tests: `test/pdf_mcq_parser_test.dart`. Not yet tried on the phone or with a real question-bank PDF (none in the project folder yet).

## Tools order (13 Nov 2026)
- Default order in `_defaultCategories()` (`tools_screen.dart`) is by importance; new last section "MCQ & Revision" (MCQ Practice, Mistake Book, Today's Revision).
- Users rearrange via Tools → "সাজান" (or long-press a tool → "টুল সাজান"): `lib/tools/tool_arrange_screen.dart`, drag tools (also across sections), ↑↓ moves sections, "আগের মতো" resets. Saved in SharedPreferences `tools_layout_v1`; `applyToolLayout` appends new tools to their default section. Empty sections are hidden. Test: `test/tool_layout_test.dart`.
