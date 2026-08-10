# iOS Share Extension (MyFrame)

OS Photos → Share → **MyFrame** uses this extension + App Group + `receive_sharing_intent`.

## What the extension does

1. **Native red-themed bottom sheet** is presented directly over the Photos share
   sheet (no Flutter app window): "Sharing to MyFrame" header with a Cancel
   button, photo count + scrolling thumbnail preview card, a "Send to" frame
   card (red frame icon, frame name, device ID/SN, red checkmark selection box),
   and a full-width rounded red **Send** button.
2. **Automatic transcoding**: every incoming image (HEIC, RAW/DNG, Display P3
   PNG screenshots, alpha/16-bit PNG) is decoded and re-encoded to a standard
   8-bit sRGB JPEG at `UIImageJPEGRepresentation(image, 0.85)`, eliminating
   color-profile decoding errors on the frame.
3. On **Send** the sanitized JPEGs are written into the App Group `Uploads/`
   directory and uploaded **directly from the extension** with a
   `URLSessionConfiguration.background` session (multipart
   `POST /api/frames/{mac}/upload`, `x-pairing-token` + Bearer JWT headers), so
   the photos keep uploading even after the share sheet closes and **without
   opening the main app**. No host redirect, no duplicate uploads.

## One-time Xcode / Apple Developer steps

1. **App Group** (Apple Developer → Identifiers → App Groups): create `group.com.myframe`.
2. Enable App Groups on both App IDs:
   - `com.myframe.minyuex` (Runner)
   - `com.myframe.minyuex.Share-Extension` (Share Extension)
3. In Xcode **Signing & Capabilities** for **Runner** and **Share Extension**, confirm App Groups includes `group.com.myframe`.
4. Confirm User-Defined build setting `CUSTOM_GROUP_ID` = `group.com.myframe` on both targets.
5. Runner **Build Phases**: `Embed Foundation Extensions` should sit **above** `Thin Binary`.
6. From `ios/`: `pod install`, then build/run on a device.

## What this repo already wires

| Piece | Value |
|-------|--------|
| App Group | `group.com.myframe` |
| Extension bundle id | `com.myframe.minyuex.Share-Extension` |
| Host URL scheme | `ShareMedia-com.myframe.minyuex` |
| Activation | images only, max 100 |
| Controller | Self-contained `ShareViewController` (native red bottom sheet + JPEG 0.85 transcoding) |
| Frame cache | Flutter host mirrors paired frames + upload targets via `ShareExtensionCache` → `ShareExtensionFrames` |
| Auth cache | Flutter host mirrors JWT → `ShareExtensionAuthToken` / `ShareExtensionAuthUserId` (App Group defaults) |
| Upload | `ShareUploader` foreground URLSession (synchronous, per-file progress, 2xx verified, playlist publish for multi-image batches) |

The extension does **not** link Flutter/`receive_sharing_intent` pods (app extensions cannot host Flutter). It uploads directly, so it never writes the `ShareKey` payload the host plugin would otherwise pick up.

Flutter mirrors frames + auth with `ShareExtensionCache.bootstrap(settings)` (bootstrapped in `main.dart`, re-synced on `DeviceStore.revision` / `AppSettings` changes).
