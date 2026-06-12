#!/usr/bin/env python3
"""
Deploy XT .bin passthrough fix to production VPS.

iOS / Flutter upload a finished 960004-byte `.bin` — the server must store those bytes
verbatim. Re-encoding with Sharp changes e-ink colors.

Run on a machine with SSH to the VPS:
  python3 scripts/fix_vps_image_passthrough.py

Requires: /var/www/myframe/backend (PM2 app myframe-api)
"""
from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path

VPS = "root@128.241.231.234"
REMOTE_BACKEND = "/var/www/myframe/backend"
LOCAL_BACKEND = Path(__file__).resolve().parents[2] / "yingxiang/Myframe_official_web/backend"
MYFM_REL = "src/services/myfm_encode.ts"
PHOTO_REL = "src/routes/photo.ts"

PHOTO_PATCH_OLD = """      let mqttBasename = basename;
      if (isProbablyMyfmBuffer(buf)) {
        mqttBasename = basename;
      } else if (encodeMyfm && looksLikeRaster) {"""

PHOTO_PATCH_NEW = """      let mqttBasename = basename;
      let imageProcessing: "client_passthrough" | "server_myfm_encode" | "stored_raw" = "stored_raw";

      if (isProbablyMyfmBuffer(buf)) {
        assertXt13e6Bin(buf);
        mqttBasename = await storeClientXtBin(buf, uploadDir, basename);
        imageProcessing = "client_passthrough";
      } else if (ext === ".bin") {
        res.status(400).json({
          ok: false,
          error: "invalid_xt_bin",
          message: `Upload must be exactly ${XT_BIN_TOTAL_BYTES} bytes with header 04 B0 06 40, or send JPEG/PNG for server encode.`,
          received_bytes: buf.length,
        });
        return;
      } else if (encodeMyfm && looksLikeRaster) {"""


def run(cmd: list[str], check: bool = True) -> subprocess.CompletedProcess:
    print("+", " ".join(cmd))
    return subprocess.run(cmd, check=check)


def patch_remote_photo() -> bool:
    remote_photo = f"{REMOTE_BACKEND}/{PHOTO_REL}"
    proc = run(["ssh", VPS, f"cat {remote_photo}"], check=False)
    if proc.returncode != 0:
        print("Could not read remote photo.ts — copy passthrough block manually.", file=sys.stderr)
        return False
    text = proc.stdout.decode() if isinstance(proc.stdout, bytes) else (proc.stdout or "")
    if PHOTO_PATCH_OLD not in text:
        print("remote photo.ts already patched or layout differs — skipped photo.ts patch", file=sys.stderr)
        return False
    text = text.replace(
        'import { isProbablyMyfmBuffer, writeMyfmSidecar } from "../services/myfm_encode";',
        'import {\n  assertXt13e6Bin,\n  isProbablyMyfmBuffer,\n  storeClientXtBin,\n  writeMyfmSidecar,\n  XT_BIN_TOTAL_BYTES,\n} from "../services/myfm_encode";',
    )
    text = text.replace(PHOTO_PATCH_OLD, PHOTO_PATCH_NEW)
    if "image_processing: imageProcessing" not in text:
        text = text.replace(
            "        image_url: imageUrl,\n      });",
            "        image_url: imageUrl,\n        image_processing: imageProcessing,\n      });",
        )
    tmp = Path("/tmp/photo.ts.patched")
    tmp.write_text(text)
    run(["scp", str(tmp), f"{VPS}:{remote_photo}"])
    return True


def main() -> int:
    if not LOCAL_BACKEND.is_dir():
        print(f"Missing local backend: {LOCAL_BACKEND}", file=sys.stderr)
        return 1

    src = LOCAL_BACKEND / MYFM_REL
    if not src.is_file():
        print(f"Missing {src}", file=sys.stderr)
        return 1
    run(["scp", str(src), f"{VPS}:{REMOTE_BACKEND}/{MYFM_REL}"])
    patch_remote_photo()

    run([
        "ssh", VPS,
        f"cd {REMOTE_BACKEND} && npm run build && pm2 restart myframe-api && pm2 status myframe-api",
    ])
    print("Done. Client `.bin` uploads use exact bytes (image_processing=client_passthrough).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
