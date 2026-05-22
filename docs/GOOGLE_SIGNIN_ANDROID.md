# Google Sign-In (Android) — one in-app picker

You need **two** OAuth clients in the same Google Cloud project (not one).

## 1. Android client (in-app picker)

[Credentials](https://console.cloud.google.com/apis/credentials) → **Create OAuth client ID** → **Android**

| Field | Value |
|--------|--------|
| Package name | `com.myframe.minyuex` |
| SHA-1 | Run on the PC that builds the APK: `bash app/scripts/print-google-sha1.sh` |

**This machine (debug) SHA-1:**

```
68:29:F9:6E:9D:40:58:02:32:2E:21:E0:19:88:76:DD:02:9C:4B:77
```

Copy the **Android client ID** (if different from Web).

## 2. Web client (idToken + server)

**Create OAuth client ID** → **Web application**

- **Authorized redirect URIs:** `https://myframe.ink/mobile/google-oauth-callback`
- **Authorized JavaScript origins:** `https://myframe.ink` (no path, no trailing `/`)

Copy:

- **Client ID** → Flutter `google_auth_config.dart` + `google_auth.xml` (`default_web_client_id`)
- **Client secret** → VPS `backend/.env` as `GOOGLE_OAUTH_CLIENT_SECRET`

## 3. `backend/.env` (VPS)

```env
GOOGLE_OAUTH_CLIENT_IDS=WEB_CLIENT_ID,ANDROID_CLIENT_ID
GOOGLE_OAUTH_CLIENT_SECRET=GOCSPX-...
PUBLIC_BASE_URL=https://myframe.ink
```

Use comma-separated IDs if Android and Web IDs differ.

## 4. Consent screen (Testing)

Add your Gmail under **Test users**.

## 5. Rebuild app

```bash
cd app
flutter clean
flutter run
```

Wait **10 minutes** after saving Google Console before testing.

## Troubleshooting

| Symptom | Fix |
|--------|-----|
| “needs Android OAuth + SHA-1” | Android client missing or SHA-1 from **another PC’s** keystore |
| Picks account then fails | Web client ID in app ≠ Web client in Console; sync `google_auth_config.dart` |
| API 401 invalid token | `GOOGLE_OAUTH_CLIENT_IDS` on VPS must include **Web** client ID |
