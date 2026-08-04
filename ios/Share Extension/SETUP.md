# iOS Share Extension (MyFrame)

OS Photos → Share → **MyFrame** uses this extension + App Group + `receive_sharing_intent`.

## One-time Xcode / Apple Developer steps

1. **App Group** (Apple Developer → Identifiers → App Groups): create `group.com.myframe.minyuex`.
2. Enable App Groups on both App IDs:
   - `com.myframe.minyuex` (Runner)
   - `com.myframe.minyuex.Share-Extension` (Share Extension)
3. In Xcode **Signing & Capabilities** for **Runner** and **Share Extension**, confirm App Groups includes `group.com.myframe.minyuex`.
4. Confirm User-Defined build setting `CUSTOM_GROUP_ID` = `group.com.myframe.minyuex` on both targets.
5. Runner **Build Phases**: `Embed Foundation Extensions` should sit **above** `Thin Binary`.
6. From `ios/`: `pod install`, then build/run on a device.

## What this repo already wires

| Piece | Value |
|-------|--------|
| App Group | `group.com.myframe.minyuex` |
| Extension bundle id | `com.myframe.minyuex.Share-Extension` |
| Host URL scheme | `ShareMedia-com.myframe.minyuex` |
| Activation | images only, max 100 |
| Controller | Self-contained `ShareViewController` (App Group + UserDefaults `ShareKey`) |

The extension does **not** link Flutter/`receive_sharing_intent` pods (app extensions cannot host Flutter). It writes the same App Group payload the host plugin reads.

Flutter listens via `ShareReceiverService` and shows `ShareTargetBottomSheetWidget`.
