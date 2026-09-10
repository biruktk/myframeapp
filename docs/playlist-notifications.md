# Playlist expansion and notification dependency

Flutter now allows 50 picks, validates the sending limit, keeps the active playlist flow file-based and sequential, and performs fallback Dart image encoding in an isolate. The legacy creation route now opens the file-based sender rather than decoding and retaining all selected images.

Playlist multipart uploads send `source=playlist`, `skip_play=true`, and `silent=true`. Direct casts do not send `silent`. After successful slideshow publishing, Flutter emits one local completion notification with the uploaded count; the hardware progress job continues silently. Partial batches do not publish or emit completion.

## Backend change — deployed 2026-09-10

The previous backend sent per-photo FCM and WeChat notifications unconditionally. Both production upload handlers now honor the explicit playlist silent flag.

`playlist-notifications-backend.patch` guards those two notification blocks only when both `source=playlist` and `silent=true` are present. Other clients and single-photo uploads retain their current behavior. After user authorization, the patch was checked against production, applied to `/var/myframe/backend/src/routes/photo.ts`, and compiled successfully. Both compiled guards passed notification eligibility checks. The compiled route was deployed and `myframe-api` restarted; `/health` returned `ok:true`. Rollback copies are in `/var/tmp/myframe-playlist-notifications.dNSzod`. The local backend mirror was not changed.

The local completion notification means all photos uploaded and the playlist publish request succeeded. It does not claim the frame has displayed every photo. The separate progress capsule continues tracking the first render ACK.

## Validation

- `flutter test test/playlist_upload_test.dart`: multipart silent flag isolation and isolate JPEG fallback pass.
- `flutter analyze`: zero errors; repository warnings and informational lint findings remain (analyzer exits nonzero for those).
- Actual 50-photo memory behavior and background notification delivery require device verification with the updated Flutter build.
