# MyFrame VPS Backend — Comprehensive Analysis

**Server:** `root@47.76.164.162` · **Path:** `/var/myframe/backend` · **PM2:** `myframe-api`
**Method:** Read-only SSH inspection (no modifications/restarts/installs).

---

## 1. Overview

Node.js / Express / TypeScript backend for MyFrame — a Wi-Fi/bluetooth smart
ePaper photo frame (XT 13.3″ E6). It:

- Talks to frames over **MQTT** (Mosquitto broker) using a custom firmware protocol.
- Serves the mobile apps (Flutter iOS/Android + WeChat Mini Program + WeChat
  mobile) for uploading photos, managing playlists/albums, family sharing,
  sleep schedules, firmware OTA, and push notifications (Firebase FCM + WeChat).
- Serves a **marketing/CMS site** (`/api/public/*`) and e-commerce checkout
  (cash-on-delivery, no real payment processor).
- Provides an **admin/management console** (`/api/admin/*`) and an **enterprise
  API** (`/api/enterprise/*`) with scoped API keys.
- Persists everything to a single **JSON file DB** (`data/myframe-db.json`).

Stack: `express`, `cors`, `mqtt`, `firebase-admin`, `sharp`, `multer`,
`jsonwebtoken`, `qrcode`, `nodemailer`, `google-auth-library`, `heic-convert`.

---

## 2. Directory Structure

```
/var/myframe/backend
├── package.json / tsconfig.json / ecosystem.config.cjs / .env(.example)
├── dist/                  (compiled JS; PM2 runs dist/index.js)
├── data/
│   ├── myframe-db.json        (1.86 MB — single-file DB, source of truth)
│   ├── frames-state.json      (in-memory MQTT frame map, persisted snapshot)
│   └── myframe-db.json.bak-*  (many backup snapshots)
├── uploads/               (frame media: .bin + .jpg/.png, thumbnails, transit)
├── secrets/               (Firebase service-account JSON if present)
└── src/
    ├── index.ts           (entry point — Express app + router mounting)
    ├── db/store.ts        (JSON-file DB read/mutate helpers)
    ├── middleware/security.ts   (token auth + rate limiting)
    ├── routes/            (26 route files)
    ├── services/          (22 service files)
    ├── handlers/          (apple/google auth post)
    └── data/              (seed/default data: marketing, blogs, firmware)
```

---

## 3. Entry Point — `src/index.ts`

- Loads `.env` from package root (`backend/.env`).
- `PORT` (default **3001**), `UPLOAD_DIR` (default `uploads`), `PUBLIC_BASE_URL`,
  `PUBLIC_MEDIA_BASE_URL` (separate plain-HTTP media origin for frames).
- Security headers (nosniff, frame-options DENY, referrer policy), `trust proxy`.
- **CORS**: allows `*.myframe.ink`, any origin in `CORS_ORIGINS`, and otherwise
  logs + allows anyway (deliberately permissive for browser form POSTs).
- Static `/frame-media` serves the upload dir (this is what frames download).
- `GET /health` → `{ ok, service, googleOAuthRedirect }`.
- Mounts **all routers under `/api`** (list in §4).
- Global error handler (HTML card for browsers, JSON for API clients).
- On listen: starts transit cleanup job, then `startFrameMqtt()`.

**Important routing order:** public/token-scoped routes are registered before
`adminRouter`, because `adminRouter` applies `requireAdminToken` to everything
that reaches it.

---

## 4. Routes (all mounted under `/api`)

### Auth — `routes/auth.ts`
- `POST /auth/register` — email+password (scrypt hash), optional email verify.
- `POST /auth/login` — scrypt + timing-safe compare, issues 30-day JWT.
- `POST /auth/test-login` — test user (`test@myframe.local`).
- `POST /auth/google` → Google ID-token login.
- `POST /auth/apple` → Apple ID-token login.
- `GET /auth/session` — validate Bearer token, return user.
- `POST /auth/fcm-token` — register FCM push token.
- `GET|POST /auth/verify-email`, `resend-verification`,
  `GET|POST /auth/reset-password`, `GET /auth/reset-password/validate`,
  `POST /auth/forgot-password` (rate-limited).

### Device — `routes/device.ts`
- `GET /device/status`, `GET /devices/:id/status` — device info.
- `POST /device/send` — push photo URL to a frame via MQTT play.

### Photos — `routes/photo.ts`
- `POST /photo/upload` (pairing token + rate limit + single file) — main upload,
  encodes to XT `.bin`, stores sidecar.
- `POST /frames/:mac/upload` — frame-scoped upload.
- `POST /invite/:code/upload`, `POST /invite/:code/upload-raw` (raw `express.raw`) —
  guest uploads via invite.
- `POST /frames/:mac/cast/batch` — batch cast.
- `GET /photo/delivery-status` — delivery progress.

### Settings — `routes/settings.ts`
- `GET/PUT /settings`, `/settings/account`, `/settings/notifications`,
  `/settings/preferences`, `/settings/integrations` (PUTs need admin token).

### Notifications — `routes/notifications.ts`
- `GET /v1/user/notifications`, `GET /notifications` — per-user + "all".
- `POST /v1/user/notifications/read`.

### Family — `routes/family.ts`
- `POST /family/create` (invite code + frameIds reconciliation).
- `POST /family/join` (cascades frame access to member).
- `GET /family/members`, `GET /family/invite` & `GET /v1/family/invite_code`.
- `DELETE /family/members/:userId`, `DELETE /family/leave`.
- `POST /family/invite/rotate` & `POST /v1/family/invite_code/regenerate`.

### Frame Slideshow — `routes/frame_slideshow.ts`
- `POST /frames/:mac/slideshow` — create/update slideshow, MQTT `strategy_bin`.
- `GET /v1/frames/manifest?mac=` — **the manifest endpoint the frame fetches**.
- `DELETE /frames/:mac/slideshow`, `POST /frames/:mac/stop-playlist`.

### Frame Pairing — `routes/frame_pairing.ts`
- `GET /frames/:mac/status` (public), `POST /frames/:mac/login-ack`,
  `POST /frames/:mac/mqtt-config`, `GET /frames/:mac/history` (pairing token).

### Frame Firmware — `routes/frame_firmware.ts`
- `GET /frames/:mac/firmware` — current vs latest, OTA status.
- `POST /frames/:mac/firmware/update` (pairing token) — triggers OTA via MQTT.
- `POST /frames/:mac/auto-update`.

### Frame Invite — `routes/frame_invite.ts`
- `POST /frame/invite`, `GET /invite/generate` — create/fetch guest invite.
- `GET /invite/:code/info` (public), `POST /invite/:code/bind-account`,
  `GET /invite/:code/qr` (PNG QR code).

### Frame Sleep — `routes/frame_sleep.ts`
- `GET|POST /frames/:mac/sleep-config` — sleep schedule, publishes UTC to frame.

### Frame Command — `routes/frame_command.ts`
- `POST /frames/:mac/mqtt-command` (pairing token) — relay `wifi_sleep` /
  `strategy_bin` / `ota`, validates payload, polls for ACK. Includes idempotency
  guard that suppresses the bundled strategy_bin on sleep-save.

### Frame Settings — `routes/frame_settings.ts`
- `GET|PUT /frames/:mac/settings` (auth) — playback config, pushes
  `UPDATE_PLAYBACK_STRATEGY` via MQTT.
- `PUT /frames/:mac/name` — custom frame name.

### Mini Program — `routes/mini_program.ts`
- `POST /mini-program/items-sold` (WeChat mini secret), `GET .../summary` —
  commerce sales tracking.

### Public Site — `routes/public_site.ts`
- `GET /public/site` (CMS payload), `GET /public/blogs`, `GET /public/blogs/by-slug/:slug`.
- `GET /public/location` (geo stub), `GET /public/customer-profile`.
- `POST /public/subscribers` ("notify me"), `POST /public/orders` (COD).
- Stripe/PayPal endpoints return `501 not configured`.

### User Portal — `routes/user_portal.ts`
- `GET /frames` (visible frames), `GET /user/dashboard`, `GET /user/gallery`.
- `GET /v1/playlists/:id/photos`, `GET /v1/albums/personal/photos`.
- `PATCH /user/playlists/:id`, `POST /user/playlists`, `POST /v1/user/albums/:id/delete-sync`.
- `DELETE /user/gallery/:id`, `/v1/user/media/:id`, `/user/playlists/:id`,
  `/v1/user/albums/:id`. `GET /v1/user/albums`.

### User Profile — `routes/user_profile.ts`
- `GET|PUT /v1/user/profile`, `POST /v1/user/avatar`.
- `POST /v1/user/frames/bind`, `POST /v1/user/frames/:frameId/unbind`,
  `DELETE /frames/:frameId` (hard delete), `GET /v1/user/frames`.

### User Playback Rules — `routes/user_playback_rules.ts`
- `GET|PUT /user/playback-rules` (display_seconds, mode, duration).

### Sync Transit — `routes/sync_transit.ts`
- `POST|GET /v1/sync/transit` — ephemeral cross-device media (TTL 2h).
- `GET/DELETE /v1/sync/transit/:packageId` — one-time download, deleted after.
- `startTransitCleanupJob()` — periodic sweeper.

### Mobile Google Auth — `routes/mobile_google_auth.ts`
- `GET /mobile/google-signin`, `GET /mobile/google-oauth-callback`,
  `POST /mobile/google-auth`.

### WeChat Mobile Auth — `routes/wechat_mobile_auth.ts`
- `POST /auth/wechat`, `POST /auth/wechat/login` (code → openid → sign user JWT).

### WeChat Phone — `routes/wechat_phone.ts`
- `POST /wechat/phone-login` (getPhoneNumber → upsert user).

### Frame Cloud — `routes/frame_cloud.ts` (self-hosted frame API, JWT)
- `POST /frame-cloud/auth/token` (`FRAME_API_SECRET`), `GET /frame-cloud/health`.
- `GET /frame-cloud/frames`, `GET /frame-cloud/frames/:mac`,
  `POST /frame-cloud/frames/:mac/play`.

### FAQ — `routes/faq.ts`
- `GET /faqs`.

### Enterprise — `routes/enterprise.ts` (org + API keys)
- `GET|POST /enterprise/orgs`, `POST /enterprise/orgs/:orgId/api-keys`,
  `GET .../api-keys`, `POST .../api-keys/:keyId/revoke`.
- `POST /enterprise/orgs/:orgId/devices/:deviceId/assign`, `GET .../devices`.
- `GET /enterprise/orgs/:orgId/uploads`, `POST .../images/upload` (scoped).
- `GET /enterprise/self/profile`, `POST /enterprise/self/api-key`.
- Admin-created keys vs self-service (user-JWT) keys; scopes
  `devices:read`, `images:write`, `images:read`, `commands:write`.

### Devs — `routes/devs.ts` (admin token)
- `GET /devs/status`, `GET /devs/logs`, `GET /devs/logs/stream` (SSE MQTT logs).

### Admin — `routes/admin.ts` (admin token)
- Overview/dashboard, commerce summary, FAQ CRUD, fleet overview.
- User list + status/tier/delete + uploads. Frame list/delete/OTA/BLE-logs.
- Upload delete, orders (list/summary/update/status), subscribers.
- Settings (basic/media/features), products CRUD, content notify/broadcast.
- Frame account-bindings, unbind-all-except-owner, unbind-user.

### CMS Manage — `routes/cms_manage_routes.ts` (admin token)
- `GET /admin/manage-state` + CRUD for: menus, social_links, footer_links,
  languages, currencies, blogs, seo, permalinks, payment-gateways, settings
  (maintenance/footer/mail/documentation/contact/translations/translated_features/
  content_pages), contact-messages, admins, upload (image/pdf).

---

## 5. Middleware — `middleware/security.ts`

- `secureEqual` — constant-time string compare.
- `requirePairingToken` — `FRAME_PAIRING_TOKEN` via `x-pairing-token`/Bearer/
  `x-admin-token`.
- `requireWechatMiniSecret` — `WECHAT_MINI_API_SECRET`.
- `requireAdminToken` — `ADMIN_TOKEN` (default `"admin"`).
- `uploadRateLimit` — token bucket per IP (`UPLOADS_PER_MINUTE`, default 30).

---

## 6. Data Model — `db/store.ts`

Single JSON file at `data/myframe-db.json` with `db.read()` / `db.write()` /
`db.mutate()`. Lazy-backfills several fields on read (orgId, frameUserRoles from
legacy, upload.source tagging, empty arrays/objects).

Key collections (from the `MyframeDb` type):
- `organizations`, `enterpriseApiKeys`
- `users` (auth, FCM tokens, WeChat openids/unionid, phone, Apple/Google subs,
  sync config, playback rules)
- `emailVerifications`, `passwordResets`
- `familyGroups` (inviteCode, members, frameIds), `frames` (ownership, roles,
  delivery progress, OTA, sleep/playback config, stationMac, battery/rssi)
- `device` (single primary frame descriptor)
- `settings`, `uploads` (with source taxonomy:
  personal_album / playlist / direct_cast / guest_invite / ai_generated),
  `playlists`, `notifications`, `bleProvisionLogs`, `featureFlags`, `auditLog`
- `syncTransitPackages`, `sleepConfigs`, `wifiSleepByBleMac`, `faqs`,
  `slideshowsByBleMac` (slideshow state per BLE MAC), `commerceEvents`,
  `notifySubscribers`, `marketingSite`, `marketingCms`, `frameUserRoles`
  (junction OWNER/MEMBER), `frameGuestInvites`, `orders`.

---

## 7. Services

- **`frame_mqtt.ts`** (46 KB — core): MQTT client to Mosquitto, subscribes to
  `/device/report/+`, `/myframe/+/ack`, `/inkjoyap/+/ack`. Maintains in-memory
  `frames` map keyed by Wi-Fi STA MAC. Handles uplinks (`heart`, `login`,
  `play_ack`, `strategy_bin_ack`, `download_complete`, `refresh_complete`,
  `strategy_stop_ack`, OTA progress). Publishes play/strategy/sleep/OTA
  commands. Resolves BLE↔STA MAC offset (±2). Defines media/manifest origins
  (ESP32 has no TLS → must use plain-HTTP media origin). Heartbeat grace:
  online 15 min, reachable 30 min. Includes time helpers (HH:MM↔UTC, windows).
- **`app_user_jwt.ts`** — user JWT sign (30d) + verify; platform normalization.
- **`photo_queue.ts`** — MQTT delivery queue per frame (30s ticker), enqueue,
  play-Ack handling, slideshow ticker (currently disabled for protocol
  compliance — strict 1-to-1: strategy_bin drives autonomous rotation).
- **`myfm_encode.ts`** — XT E6 `.bin` encoder: 1200×1600, 4bpp, left/right
  halves, custom 6-colour palette, Floyd–Steinberg dithering, Sharp
  preprocessing; verifies/accepts client-encoded `.bin`; HEIC→JPEG fallback.
- **`slideshow_index.ts`** — sequential/random index helpers.
- **`slideshow_stop.ts`** — powerful playlist/album delete sync; `strategy_stop`
  only (frame keeps last image), idempotency cooldown per MAC.
- **`album_delete_sync.ts`** — `ALBUM_DELETE_SYNC` firmware protocol.
- **`firebase_admin.ts`** — FCM push with localized (en/zh) strings; resolves
  owner + shared + family recipients; prunes invalid tokens.
- **`wechat_subscribe_notify.ts`** — WeChat subscribe-message push with quota
  tracking + dedup; records in-app notifications.
- **`email_service.ts`** — nodemailer verify/reset/password-changed emails.
- **`account_sync_state.ts`** — sync versions, family frame access, visible
  frames, playlist metadata.
- **`frame_user_roles.ts`** — OWNER/MEMBER junction table + migration/backfill.
- **`enterprise_api_keys.ts`** — scoped API key auth, sha256 hashing, key gen.
- **`frame_guest_invite.ts`** — 8-char invite codes.
- **`apple_auth_session.ts` / `apple_id_token.ts`** — Apple Sign-In (JWKS verify).
- **`google_auth_session.ts` / `google_id_token.ts` / `google_oauth_mobile.ts`** —
  Google login + mobile OAuth redirect flow.
- **`marketing_public.ts`** — site payload merge + SKU price map.
- **`frame_logs.ts`** — in-memory 2000-entry MQTT rx/tx ring buffer + SSE.

---

## 8. Data / Seed Files — `src/data/`

- `firmware_releases.ts` — latest firmware default **0.0.2** (host 47.76.164.162,
  plain HTTP :80, `/firmware/myframe-firmware-0.0.2.bin`), version compare helpers
  (env-overridable).
- `marketing_defaults.ts`, `blog_defaults.ts`, `marketing_content_pages_default.ts`,
  `marketing_official_pages_snapshot.json` — CMS seed content.

---

## 9. Handlers

- `apple_auth_post.ts` — validates Apple identity token → completeAppleLogin.
- `google_auth_post.ts` — validates Google ID token → completeGoogleLogin
  (shared by `/auth/google` and `/mobile/google-auth`).

---

## 10. Configuration & Deployment

- `ecosystem.config.cjs`: PM2 fork mode, max 512M memory restart.
- `.env.example` lists all env vars: PORT, UPLOAD_DIR, TRANSIT_DIR, CORS_ORIGINS,
  FRAME_PAIRING_TOKEN, ADMIN_TOKEN, WECHAT_MINI_API_SECRET, MQTT_URL/USER/PASSWORD,
  FRAME_MQTT_*, PUBLIC_BASE_URL, PUBLIC_MEDIA_BASE_URL, FRAME_MANIFEST_*,
  FRAME_API_SECRET, FRAME_JWT_SECRET, APP_JWT_SECRET, WECHAT_* (mini/mobile
  appid/secret), GOOGLE_OAUTH_*, Apple client IDs, FIREBASE_SERVICE_ACCOUNT_*,
  SMTP_*, FRAME_PLAY_ALLOW_HTTPS, FRAME_IDLE_PLAY_URL, FIRMWARE_*, etc.
- PM2: `myframe-api` (main), `myframe-flasher`, `myframe-web`.

---

## 11. Runtime Data

- **`data/frames-state.json`** — map keyed by MAC with `lastSeen`, `status`,
  `config.firmwareVersion` (e.g. `M H:3 F:0.5.0`), `clientid`, `lastAction`
  (`heart`), `battery`, `wifiName`, etc.
- **`data/myframe-db.json`** (1.86 MB) — all app state; many `.bak` snapshots
  showing a history of migrations (family heal, frame roles, playback rules,
  protocol overhaul, sleepoff, e2e).
- **`uploads/`** — pairs of `<ts>_tmp|photo_<rand>.<bin>` + sidecar
  `.jpg`/`.png` (the `.bin` is the display payload). Subdirs for thumbnails,
  shares, slideshows, transit.

---

## 12. Key Architectural Notes / Observations

1. **Single-file JSON DB** — no SQL; simple but scales via in-memory caches;
   `db.mutate` reads+writes the whole file each call (fine at this scale).
2. **Firmware protocol is strict ("1-to-1")** — the server deliberately does NOT
   push individual `play` commands for active playlists; the frame cycles
   autonomously after receiving `strategy_bin`. Stops use `strategy_stop` only
   (no fallback play) so the last image stays displayed.
3. **ESP32 has no TLS / hostname resolution** — all frame-facing URLs must use
   the plain-HTTP media origin (`PUBLIC_MEDIA_BASE_URL`, e.g. `47.76.164.162:80`),
   not the HTTPS marketing site; careful host/port rewriting in `frame_mqtt.ts`.
4. **MAC normalization** — BLE↔STA MAC offset of 2; multiple id/MAC spellings
   always normalize to a canonical hardware MAC before MQTT dispatch to avoid
   double-dispatches.
5. **Multi-origin auth** — user JWTs, pairing token, admin token, WeChat mini
   secret, enterprise API keys, self-hosted frame-cloud JWT — several parallel
   auth schemes.
6. **Marketing + commerce are embedded** in the backend (CMS CRUD, COD orders,
   Stripe/PayPal stubbed out).
7. **CORS is permissive by design** (logs then allows), which is pragmatic for
   the marketing site but worth noting from a security standpoint.
