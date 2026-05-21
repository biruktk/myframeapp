# Google Sign-In (Android / iOS)

## Error 400 `invalid_request` (what you saw)

That screen means Google rejected the sign-in request. Fix it in **Google Cloud Console** (one-time):

### 1. OAuth consent screen

[OAuth consent screen](https://console.cloud.google.com/apis/credentials/consent)

- App name: **MyFrame** (or your product name)
- User support email: your email
- Developer contact: your email
- If status is **Testing**: add **Test users** → `birukindrias@gmail.com` (every account that will sign in)

### 2. Web OAuth client (used for mobile browser fallback)

[Credentials](https://console.cloud.google.com/apis/credentials) → your **Web application** client  
(`824694546060-…apps.googleusercontent.com`)

**Authorized redirect URIs** (must match `PUBLIC_BASE_URL` on the VPS — often):

```
https://myframe.ink/mobile/google-oauth-callback
```

(If `PUBLIC_BASE_URL=http://128.241.231.234:3001`, use that host instead, with no trailing slash.)

**Authorized JavaScript origins** (only if you still use the old GIS button page):

```
http://128.241.231.234:3001
```

Copy the Web client **Client secret** into VPS `backend/.env`:

```env
GOOGLE_OAUTH_CLIENT_SECRET=GOCSPX-xxxxxxxx
PUBLIC_BASE_URL=https://myframe.ink
```

Then on the VPS:

```bash
cd /var/www/myframe/backend
git pull
npm run build
pm2 restart myframe-api
curl -s http://127.0.0.1:3001/health
# expect: "googleOAuthRedirect": true
```

Wait ~5–10 minutes after saving Google Console, then try again in the app.

### 3. Native in-app Gmail picker (optional, best UX)

**Create OAuth client ID** → **Android**

- Package: `com.myframe.minyuex`
- SHA-1: run `app/scripts/print-google-sha1.sh` on the machine that builds the APK

Keep the **Web** client ID in `GOOGLE_OAUTH_CLIENT_IDS` and in the app (`google_auth_config.dart` / `google_auth.xml`).

## App flow

1. Tries **native** Google account picker (needs Android OAuth + SHA-1).
2. If that fails → opens **Custom Tab** → `/mobile/google-signin` → redirects to Google → returns via `myframe://auth/google`.

Rebuild after Flutter changes:

```bash
cd app && flutter clean && flutter run
```
