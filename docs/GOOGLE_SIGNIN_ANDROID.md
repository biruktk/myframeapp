# In-app Google Sign-In (Android)

The app uses the **native** Google account picker (stays inside MyFrame — no Chrome).

## Google Cloud Console (one-time)

1. [Credentials](https://console.cloud.google.com/apis/credentials) → **Create OAuth client ID** → **Android**
2. Package name: `com.myframe.minyuex`
3. SHA-1: run `app/scripts/print-google-sha1.sh` on the machine that builds the APK
4. Keep the existing **Web** client ID in server `GOOGLE_OAUTH_CLIENT_IDS`

Wait ~10 minutes, then `flutter clean && flutter run`.

## Browser fallback

`/mobile/google-signin` on the API is only for emergencies; the mobile app does not open it by default.
