# MyFrame Flutter App

Mobile app (`iOS` + `Android`) for MyFrame: Home, Send Photo, Playlist, Family, Settings, bottom navigation.

This is the canonical Flutter project in the repo (see root `README.md`).

## Run

If `flutter --version` fails, reinstall the SDK from https://docs.flutter.dev/get-started/install/linux and ensure `which flutter` points at `flutter/bin/flutter`.

```bash
cd app
flutter pub get
flutter run
```

**Production API URL (built in — no `--dart-define` required)**

- **`lib/config/vps_defaults.dart`** defines the default Express API as **`http://47.76.164.162:3001`** (raw IP — same VPS as typical MQTT/media).
- **`lib/config/api_config.dart`** uses that whenever **`API_BASE`** is **not** passed at compile time.
- **Android**: emulator still often needs **`--dart-define=API_BASE=http://10.0.2.2:3001`** to hit the host PC.
- **iOS Simulator with API on Mac**: optional **`API_BASE=http://127.0.0.1:3001`**.
- **Marketing host** (often DNS‑fragile on cellular): **`http://myframe.ink:3001`** — also listed under **`ios/Runner/Info.plist`** keys `MyframeApiBase` / `MyframeInkHost` for Xcode reference; Flutter still prefers the **IP** from `VpsDefaults` unless you pass **`--dart-define=API_BASE=http://myframe.ink:3001`**.

### Android

`android/app/src/main/AndroidManifest.xml` declares **INTERNET**, **CAMERA**, **BLE** scan/connect permissions, and **`usesCleartextTraffic="true"`** so `http://` to a dev server or frame on the LAN works (use HTTPS in production).

### iOS (build on a Mac with Xcode)

1. From `app/`, after `flutter pub get`, the first iOS build also pulls pods. If you open Xcode manually, run once:
   `cd ios && pod install` then open `ios/Runner.xcworkspace` (not `.xcodeproj`).

2. **API URL**: same **`ApiConfig.baseUrl`** as Android (~**`VpsDefaults.apiBase`** / **`MyframeApiBase`** in plist). Run **`flutter run`** from Xcode or CLI — no VPS `--dart-define` needed for production. XT **`.bin`**: **`lib/services/image_processor_service.dart`**.

   - API on **the same Mac** (Simulator): pass **`API_BASE=http://127.0.0.1:3001`** if you rely on localhost.
   - **Physical iPhone** against production: default built-in VPS IP (**`plist` ⇄ Dart**) is fine for cleartext **`:3001`**.

3. `ios/Runner/Info.plist` includes:
   - **MyframeApiBase** / **MyframeInkHost** strings (mirror Dart defaults; Xcode reference only unless you wire native reads later).
   - **NSCameraUsageDescription** and **NSPhotoLibraryUsageDescription** (QR + gallery/camera in Send).
   - **NSAppTransportSecurity** → **NSAllowsLocalNetworking** and **NSAllowsArbitraryLoads** so **`http://` to LAN and to a public VPS IP** works (required for typical XT `MQTT play`/`frame-media` over HTTP). Tighten to HTTPS/host exceptions before a strict App Store review if needed.

4. **Expected `.bin` from the app**: **960004** bytes; first four bytes **`04 B0 06 40`** (big-endian 1200, 1600). No MYFM header.

Uploads: `device_id`, `checksum`, `size`, optional `slideshow_style` and `transport` (see `../web/backend/` and `lib/services/frame_api_client.dart`).
If pairing QR includes `pairingToken`, app sends it as `x-pairing-token` on HTTP status/upload calls.

`lib/main.dart` uses `MainShell`, theme, and localization from Settings.

- **Wi‑Fi sends** use `FrameApiClient` → `POST /api/photo/upload` (see `lib/services/frame_api_client.dart`).  
- **Bluetooth**: if pairing includes `apiUrl` and the phone has a **network link** (Wi‑Fi or cellular), the app uses the **HTTP** upload with `transport=bluetooth`; if there is **no** link, it still sends to the frame via **`BleFrameDeviceTransport`** (GATT) without a server. Pure BLE when `apiUrl` is absent is unchanged.  
- **`MockDeviceTransport`** in `lib/services/device_transport.dart` is only a test double; the app wires **`BleFrameDeviceTransport`** in `lib/main.dart`.
# myframeapps
# myframeapps
# myframeapps
# myframeappfl
# myframeapp
# myframeapp
