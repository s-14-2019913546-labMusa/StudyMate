# Firebase Storage rules (Blaze plan)

Firebase console → Storage → Rules → paste this and press **Publish**.
These cover every path the app uploads to.

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    function signedIn() { return request.auth != null; }
    function smallerThan(mb) { return request.resource.size < mb * 1024 * 1024; }
    function isImage() { return request.resource.contentType.matches('image/.*'); }

    // Profile photo: anyone signed in can see it, only the owner can change it
    match /profile_photos/{file} {
      allow read: if signedIn();
      allow write: if signedIn() && file == request.auth.uid + '.jpg' && smallerThan(2);
    }

    // Cloud backup: only the owner
    match /backups/{uid}/{file} {
      allow read, write: if signedIn() && request.auth.uid == uid && (request.resource == null || smallerThan(20));
    }

    // Note images / voice notes: file name starts with the owner's uid
    match /notes_images/{file} {
      allow read: if signedIn();
      allow write: if signedIn() && file.matches(request.auth.uid + '_.*') && smallerThan(10);
    }
    match /notes_audio/{file} {
      allow read: if signedIn();
      allow write: if signedIn() && file.matches(request.auth.uid + '_.*') && smallerThan(20);
    }

    // Chat files and group photos
    match /chat_media/{chatId}/{file} {
      allow read: if signedIn();
      allow write: if signedIn() && smallerThan(20);
    }
    match /group_photos/{file} {
      allow read: if signedIn();
      allow write: if signedIn() && isImage() && smallerThan(5);
    }
  }
}
```

## To avoid a surprise bill
- Google Cloud console → Billing → **Budgets & alerts** → create a budget of e.g. $1 with email alerts.
- Storage free tier (Blaze): 5 GB stored, ~1 GB download/day. The size limits above keep single files small.
