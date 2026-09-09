# MyFrame Intents Extension (iOS Direct Share Targets)

Adds MyFrame frame targets to the **top circular row of the native iOS Share
Sheet** (Frameo / QQ-style 1-tap direct sharing).

## How it works
- **Donation (implemented + wired)**: `FrameShortcutPlugin` is embedded in
  `ios/Runner/AppDelegate.swift` + `lib/services/frame_shortcut_service.dart`.
  When the app sets a frame as
  active (`DeviceStore.setActiveFrameDeviceId`), it donates an `INInteraction`
  containing an `INSendMessageIntent` whose recipient `INPerson` is the frame
  (displayName = frame name, handle = frame MAC). iOS ranks that recipient in
  the Share Sheet's suggestion row.
- **Handling (this folder)**: `IntentHandler.swift` confirms + handles the
  `INSendMessageIntent`, writing the chosen frame MAC to the shared App Group so
  the existing MyFrame Share Extension can route the image to that frame.

## Required Xcode steps (must be done in Xcode — NOT automated)
Editing `project.pbxproj` to add an app-extension target by hand is fragile and
can break the whole Xcode build, so do these in Xcode:

1. **Add the Intents Extension target**
   `File → New → Target → iOS → App Extension → Intents Extension`
   Name it **`MyFrameIntents`**, product name `MyFrameIntents`, bundle id
   `com.myframe.minyuex.Intents`, and **de-select** "Include UI Extension".

2. **Replace the generated `IntentHandler.swift`** with
   `ios/MyFrameIntents/IntentHandler.swift`. (Drag the file into the target's
   "Compile Sources" and remove the auto-generated one if any.)

3. **Configure the extension's Info.plist**
   - `NSExtensionPointIdentifier` = `com.apple.intents-service`
   - `NSExtensionPrincipalClass` = `IntentHandler`
   - Add the following intent definitions (copy from shared Intents or declare
     the `INSendMessageIntent` is used — the handler implements
     `INSendMessageIntentHandling`):
     ```xml
     <key>NSExtension</key>
     <dict>
       <key>NSExtensionAttributes</key>
       <dict>
         <key>IntentsSupported</key>
         <array>
           <string>INSendMessageIntent</string>
         </array>
       </dict>
       <key>NSExtensionPointIdentifier</key>
       <string>com.apple.intents-service</string>
       <key>NSExtensionPrincipalClass</key>
       <string>$(PRODUCT_MODULE_NAME).IntentHandler</string>
     </dict>
     ```
   - Add an **`AppGroupId`** Info.plist key set to `group.com.myframe` (or
     `group.com.myframe.app`) — used by `IntentHandler.appGroupId`.

4. **App Group (already configured for the Share Extension — reuse it)**
   - Runner, Share Extension, **and MyFrameIntents** must all enable the same
     App Group capability (`group.com.myframe`) in
     `Signing & Capabilities → App Groups`.
   - The Runner already has `Runner.entitlements` with the group; add the group
     entitlement to the Intents Extension's entitlements file too.

5. **Embed the extension**
   In Runner target → General → Frameworks, Libraries, Embedded Content → add
   `MyFrameIntents.appex`. Set `Embed & Sign`.

## Versioning / deployment notes
- App Groups + Intents Extension require a real Apple Developer team
  (already set: `MKXW4C834N`) and a provisioning profile that includes the
  extension. TestFlight/internal builds need the extension presented.
- Donations are best-effort: iOS/Siri re-ranks the suggestion row on its own
  schedule (usually after a few real shares), so the shortcut may not appear
  immediately on first install.
