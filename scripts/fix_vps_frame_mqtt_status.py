#!/usr/bin/env python3
"""
Deploy frame MQTT status fix to production VPS.

Problem: /api/frames/:mac/status returned mqtt_connected:false even when the
frame was online. Apps blocked sends. This patch adds frame_pairing routes that
set mqtt_connected from live MQTT heart/login reports.

Run from repo root (needs SSH to VPS):
  python3 scripts/fix_vps_frame_mqtt_status.py
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

VPS = "root@128.241.231.234"
REMOTE_BACKEND = "/var/www/myframe/backend"
# VPS production matches myframe_website/backend (device.ts has /frames/:mac/status).
LOCAL_BACKEND = Path(__file__).resolve().parents[2] / "myframe_website/backend"
LOCAL_BACKEND_ALT = Path(__file__).resolve().parents[2] / "yingxiang/Myframe_official_web/backend"

FILES = [
    "src/services/frame_mqtt.ts",
    "src/routes/device.ts",
    "scripts/vps_patch_frame_mqtt_status_on_server.py",
]


def run(cmd: list[str], check: bool = True) -> subprocess.CompletedProcess:
    print("+", " ".join(cmd))
    return subprocess.run(cmd, check=check)


def main() -> int:
    local_root = LOCAL_BACKEND if LOCAL_BACKEND.is_dir() else LOCAL_BACKEND_ALT
    if not local_root.is_dir():
        print(f"Local backend not found: {LOCAL_BACKEND} or {LOCAL_BACKEND_ALT}", file=sys.stderr)
        return 1

    for rel in FILES:
        local = local_root / rel
        if not local.is_file() and rel.startswith("scripts/"):
            local = Path(__file__).resolve().parent / Path(rel).name
        remote = f"{REMOTE_BACKEND}/{rel}"
        if not local.is_file():
            print(f"Missing {local}", file=sys.stderr)
            return 1
        run(["scp", str(local), f"{VPS}:{remote}"])

    run(
        [
            "ssh",
            VPS,
            f"cd {REMOTE_BACKEND} && npm run build && pm2 restart myframe-api --update-env",
        ],
    )
    print("Deployed. Verify:")
    print("  curl -sS https://myframe.ink/api/frames/D0CF13F0161C/status")
    print("  curl -sS https://myframe.ink/api/frame-cloud/health")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
