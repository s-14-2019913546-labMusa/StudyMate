# Firestore rules: what to add

New features save data in places your current Firestore rules don't allow yet
(the phone log shows `PERMISSION_DENIED` for `users/{uid}/mistakes`,
`mcq_questions`, `mcq_results`).

How to add: Firebase console → project **studymate-5ab8c** → Firestore Database →
**Rules** tab. Paste the block below **inside** the existing
`match /databases/{database}/documents { ... }` block (next to your other
`match` lines). Don't delete anything that's already there. Click **Publish**.

Firestore rules only *add* permissions, so this can't break existing features.
It costs nothing (rules are free on the Spark plan).

```
    // Each user can read/write everything under their own users/{uid} document
    // (notes, mistakes, MCQ questions/results, backups, streak freezes, ...)
    match /users/{uid}/{rest=**} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }

    // Q&A forum: any signed-in user can read and post; only the author can delete
    match /forum_posts/{postId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null
                    && request.resource.data.authorId == request.auth.uid;
      allow update: if request.auth != null;   // answer count, votes
      allow delete: if request.auth != null
                    && resource.data.authorId == request.auth.uid;

      match /answers/{answerId} {
        allow read: if request.auth != null;
        allow create: if request.auth != null
                      && request.resource.data.authorId == request.auth.uid;
        allow update: if request.auth != null;   // votes, "best answer"
        allow delete: if request.auth != null
                      && resource.data.authorId == request.auth.uid;
      }
    }
```

The user document itself (`users/{uid}`) also gets new fields:
`weeklyStudyMinutes`, `weeklyStudyWeek`, `dailyGoalMinutes`, `streakFreezes`,
`studyingNow`. If your existing rule for `users/{uid}` limits which fields can be
written, allow these as well.
