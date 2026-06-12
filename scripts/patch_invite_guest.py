#!/usr/bin/env python3
"""Patch VPS myframe backend for guest invite info/upload/qr."""
from pathlib import Path

ROOT = Path("/var/www/myframe/backend/src")

# --- security.ts ---
sec = ROOT / "middleware/security.ts"
st = sec.read_text()
if "params?.code" not in st:
    st = st.replace(
        """export function inviteCodeFromRequest(req: Request): string {
  return String(
    req.header("x-invite-code") ??
      req.body?.invite_code ??
      req.body?.inviteCode ??
      "",
  )""",
        """export function inviteCodeFromRequest(req: Request): string {
  const params = req.params as { code?: string } | undefined;
  return String(
    params?.code ??
      req.header("x-invite-code") ??
      req.body?.invite_code ??
      req.body?.inviteCode ??
      "",
  )""",
    )
    st = st.replace(
        "export function requirePairingTokenOrInvite(req: Request, res: Response, next: NextFunction) {\n  const code = inviteCodeFromRequest(req);",
        """export function requirePairingTokenOrInvite(req: Request, res: Response, next: NextFunction) {
  const preset = (req as Request & { frameInviteDeviceId?: string }).frameInviteDeviceId;
  if (preset) {
    next();
    return;
  }
  const code = inviteCodeFromRequest(req);""",
    )
    sec.write_text(st)
    print("security.ts ok")

# --- photo.ts ---
photo = ROOT / "routes/photo.ts"
pt = photo.read_text()
if "frameMacUploadHandler" not in pt:
    pt = pt.replace(
        'import { registerUserGalleryPhoto } from "../services/user_gallery_service";',
        'import { registerUserGalleryPhoto } from "../services/user_gallery_service";\nimport { lookupFrameInviteDeviceId } from "../services/frame_guest_invite";',
    )
    pt = pt.replace(
        '  router.post("/frames/:mac/upload", requirePairingTokenOrInvite, uploadRateLimit, upload.single("photo"), async (req, res) => {',
        '  const frameMacUploadHandler = async (req: express.Request, res: express.Response) => {',
    )
    pt = pt.replace(
        '  });\n\n  router.post("/photo/upload",',
        '  };\n\n  router.post(\n    "/frames/:mac/upload",\n    requirePairingTokenOrInvite,\n    uploadRateLimit,\n    upload.single("photo"),\n    frameMacUploadHandler,\n  );\n\n  router.post(\n    "/invite/:code/upload",\n    (req, res, next) => {\n      const code = String(req.params.code ?? "")\n        .trim()\n        .toUpperCase()\n        .replace(/[^A-Z0-9]/g, "");\n      if (code.length !== 8) {\n        res.status(400).json({ ok: false, error: "invalid_invite_code" });\n        return;\n      }\n      const deviceId = lookupFrameInviteDeviceId(code);\n      if (!deviceId) {\n        res.status(404).json({ ok: false, error: "invite_not_found" });\n        return;\n      }\n      (req as express.Request & { frameInviteDeviceId?: string }).frameInviteDeviceId = deviceId;\n      next();\n    },\n    requirePairingTokenOrInvite,\n    uploadRateLimit,\n    upload.single("photo"),\n    frameMacUploadHandler,\n  );\n\n  router.post("/photo/upload",',
    )
    pt = pt.replace(
        '      const deviceId = String(req.params.mac ?? req.body.mac ?? req.body.device_id ?? "");',
        '      const deviceId = String(\n        (req as express.Request & { frameInviteDeviceId?: string }).frameInviteDeviceId ??\n          req.params.mac ??\n          req.body.mac ??\n          req.body.device_id ??\n          "",\n      );',
        1,
    )
    photo.write_text(pt)
    print("photo.ts ok")

# --- frame_invite.ts ---
fi = ROOT / "routes/frame_invite.ts"
ft = fi.read_text()
if "/invite/:code/info" not in ft:
    if "import QRCode" not in ft:
        ft = ft.replace(
            'import { verifyUserJwtBearer } from "../services/app_user_jwt";',
            'import QRCode from "qrcode";\nimport { verifyUserJwtBearer } from "../services/app_user_jwt";',
        )
    block = '''

function normalizeInvitePathCode(raw: string): string {
  return String(raw ?? "")
    .trim()
    .toUpperCase()
    .replace(/[^A-Z0-9]/g, "");
}

/** GET /api/invite/:code/info — guest send screen (WeChat mini program). */
frameInviteRouter.get("/invite/:code/info", (req, res) => {
  const code = normalizeInvitePathCode(String(req.params.code ?? ""));
  if (code.length !== 8) {
    res.status(400).json({ ok: false, error: "invalid_invite_code" });
    return;
  }
  const row = db.read().frameGuestInvites?.find((r) => r.code === code);
  if (!row) {
    res.status(404).json({ ok: false, error: "invite_not_found" });
    return;
  }
  const inviteUrl = `${publicInviteBaseUrl()}/invite/${code}`;
  res.json({
    ok: true,
    success: true,
    inviteCode: code,
    code,
    inviteUrl,
    link: inviteUrl,
    url: inviteUrl,
    frameMac: row.deviceId,
    deviceId: row.deviceId,
    frameName: `MY_${row.deviceId}`,
    fromServer: true,
  });
});

/** GET /api/invite/:code/qr — PNG QR (Share QR Code). */
frameInviteRouter.get("/invite/:code/qr", async (req, res) => {
  try {
    const code = normalizeInvitePathCode(String(req.params.code ?? ""));
    if (code.length !== 8) {
      res.status(400).json({ ok: false, error: "invalid_invite_code" });
      return;
    }
    const row = db.read().frameGuestInvites?.find((r) => r.code === code);
    if (!row) {
      res.status(404).json({ ok: false, error: "invite_not_found" });
      return;
    }
    const inviteUrl = `${publicInviteBaseUrl()}/invite/${code}`;
    const png = await QRCode.toBuffer(inviteUrl, { type: "png", width: 480, margin: 2, errorCorrectionLevel: "M" });
    res.setHeader("Content-Type", "image/png");
    res.setHeader("Cache-Control", "public, max-age=300");
    res.send(png);
  } catch (e) {
    console.error("[invite-qr]", e);
    res.status(500).json({ ok: false, error: "qr_generate_failed" });
  }
});
'''
    fi.write_text(ft.rstrip() + block + "\n")
    print("frame_invite.ts ok")
