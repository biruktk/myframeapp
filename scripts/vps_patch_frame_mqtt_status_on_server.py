#!/usr/bin/env python3
"""
Run ON THE VPS (not your Mac):
  cd /var/www/myframe/backend
  python3 scripts/vps_patch_frame_mqtt_status_on_server.py

Patches frame MQTT status so mqtt_connected reflects the FRAME heartbeat,
not the API broker flag. Also fixes MAC lookup (IJ_D0CF13F0161C → D0CF13F0161C).
"""
from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

ROOT = Path("/var/www/myframe/backend")
SRC = ROOT / "src"


def read(rel: str) -> str:
    p = SRC / rel
    if not p.is_file():
        print(f"MISSING {p}", file=sys.stderr)
        sys.exit(1)
    return p.read_text()


def write(rel: str, text: str) -> None:
    p = SRC / rel
    p.write_text(text)
    print(f"patched {p}")


def patch_frame_mqtt() -> None:
    rel = "services/frame_mqtt.ts"
    text = read(rel)

    if "export function isFrameMqttOnline" not in text:
        insert_before = "export function isMqttConnected(): boolean {"
        block = """
/** True when the frame published login/heart/play on MQTT recently. */
export function isFrameMqttOnline(macRaw: string, maxAgeMs = 120_000): boolean {
  const rec = getFrame(macRaw);
  if (!rec) return false;
  return Date.now() - rec.lastSeen <= maxAgeMs;
}

function mqttBrokerDefaults() {
  const host = String(process.env.FRAME_MQTT_BROKER_HOST ?? "47.76.164.162").trim();
  const port = Number(process.env.FRAME_MQTT_BROKER_PORT ?? 1883) || 1883;
  const usr = String(process.env.FRAME_MQTT_DEVICE_USER ?? "device").trim();
  const pwd = String(process.env.FRAME_MQTT_DEVICE_PASS ?? "framepass2026").trim();
  return { host, port, usr, pwd };
}

function publishJson(topic: string, payload: Record<string, unknown>, retain = false): Promise<void> {
  return new Promise((resolve, reject) => {
    if (!mqttClient?.connected) {
      reject(new Error("MQTT not connected"));
      return;
    }
    const body = JSON.stringify(payload);
    mqttClient.publish(topic, body, { qos: 1, retain }, (err) => {
      if (err) reject(err);
      else resolve();
    });
  });
}

export function publishRetainedMqttConfig(macRaw: string, msgid?: string): Promise<void> {
  const mac = resolveMqttHardwareMac(macRaw);
  if (!mac) return Promise.reject(new Error("invalid_mac"));
  const broker = mqttBrokerDefaults();
  return publishJson(
    `/inkjoyap/${mac}`,
    {
      msgid: msgid ?? Date.now().toString(),
      action: "mqtt_config",
      stamac: mac,
      data: { host: broker.host, port: broker.port, usr: broker.usr, pwd: broker.pwd },
    },
    true,
  );
}

export function publishLoginAck(macRaw: string, msgid?: string): Promise<void> {
  const mac = resolveMqttHardwareMac(macRaw);
  if (!mac) return Promise.reject(new Error("invalid_mac"));
  return publishJson(`/inkjoyap/${mac}`, {
    msgid: msgid ?? Date.now().toString(),
    action: "login_ack",
    stamac: mac,
    data: { ack: 1 },
  });
}

"""
        if insert_before not in text:
            print("Could not insert frame_mqtt helpers", file=sys.stderr)
            sys.exit(1)
        text = text.replace(insert_before, block + insert_before)

    old_mac = "const mac = normalizeMac(clientid);"
    new_mac = """const mac =
    resolveMqttHardwareMac(clientid) ??
    resolveMqttHardwareMac(tail) ??
    (normalizeMac(clientid).length === 12 ? normalizeMac(clientid) : null);"""
    if old_mac in text:
        text = text.replace(old_mac, new_mac)

    old_get = """export function getFrame(macRaw: string): (FrameRecord & { mac: string; age: number }) | null {
  const mac = normalizeMac(macRaw);
  const rec = frames.get(mac);
"""
    new_get = """export function getFrame(macRaw: string): (FrameRecord & { mac: string; age: number }) | null {
  const mac = resolveMqttHardwareMac(macRaw);
  if (!mac) return null;
  const rec = frames.get(mac);
"""
    if old_get in text:
        text = text.replace(old_get, new_get)

    if "rec.lastAction" not in text and "rec.status = \"online\";" in text:
        text = text.replace(
            'rec.status = "online";',
            'rec.status = "online";\n  rec.lastAction = action || rec.lastAction;',
        )

    write(rel, text)


def patch_device_status() -> None:
    rel = "routes/device.ts"
    text = read(rel)

    if "mqtt_connected: isMqttConnected()" in text:
        text = text.replace(
            "mqtt_connected: isMqttConnected(),",
            "mqtt_connected: frameLive,\n    api_mqtt_connected: isMqttConnected(),\n    frame_mqtt_live: frameLive,",
        )

    if "const mqttOnline = !!mqttFrame && mqttFrame.age < 120000;" in text:
        text = text.replace(
            "const mqttOnline = !!mqttFrame && mqttFrame.age < 120000;",
            "const frameLive = isFrameMqttOnline(requestedMac);\n  const mqttOnline = frameLive;",
        )
    elif "const frameLive = isFrameMqttOnline" not in text and 'deviceRouter.get("/frames/:mac/status"' in text:
        text = text.replace(
            "const mqttFrame = getFrame(req.params.mac);",
            "const requestedMac = resolveMqttHardwareMac(req.params.mac) ?? String(req.params.mac ?? \"\");\n  const mqttFrame = getFrame(requestedMac);\n  const frameLive = isFrameMqttOnline(requestedMac);",
        )

    if "isFrameMqttOnline" in text and "import {" in text and "isFrameMqttOnline" not in text.split("from \"../services/frame_mqtt\"")[0]:
        text = text.replace(
            "import { getFrame, isMqttConnected, publishPlayImage, resolveMqttHardwareMac }",
            "import { getFrame, isFrameMqttOnline, isMqttConnected, publishLoginAck, publishPlayImage, publishRetainedMqttConfig, resolveMqttHardwareMac }",
        )
        if "requirePairingToken" not in text:
            text = text.replace(
                'import { Router } from "express";',
                'import { Router } from "express";\nimport { requirePairingToken } from "../middleware/security";',
            )

    if 'deviceRouter.post("/frames/:mac/login-ack"' not in text:
        text = text.rstrip() + """

deviceRouter.post("/frames/:mac/login-ack", requirePairingToken, async (req, res) => {
  const mac = resolveMqttHardwareMac(String(req.params.mac ?? ""));
  if (!mac) { res.status(400).json({ ok: false, error: "invalid_mac" }); return; }
  const msgid = String((req.body as { msgid?: string })?.msgid ?? Date.now());
  try {
    await publishLoginAck(mac, msgid);
    res.json({ ok: true, stamac: mac, msgid });
  } catch (err) {
    res.status(isMqttConnected() ? 502 : 503).json({ ok: false, error: err instanceof Error ? err.message : "mqtt_publish_failed" });
  }
});

deviceRouter.post("/frames/:mac/mqtt-config", requirePairingToken, async (req, res) => {
  const mac = resolveMqttHardwareMac(String(req.params.mac ?? ""));
  if (!mac) { res.status(400).json({ ok: false, error: "invalid_mac" }); return; }
  const msgid = String((req.body as { msgid?: string })?.msgid ?? Date.now());
  try {
    await publishRetainedMqttConfig(mac, msgid);
    res.json({ ok: true, stamac: mac, msgid, delivery_mode: "vps_mqtt_config_retain" });
  } catch (err) {
    res.status(isMqttConnected() ? 502 : 503).json({ ok: false, error: err instanceof Error ? err.message : "mqtt_publish_failed" });
  }
});
"""

    write(rel, text)


def main() -> int:
    if not ROOT.is_dir():
        print(f"Expected VPS backend at {ROOT}", file=sys.stderr)
        return 1
    print("=== grep mqtt_connected before ===")
    subprocess.run(["grep", "-rn", "mqtt_connected", str(SRC)], check=False)
    patch_frame_mqtt()
    patch_device_status()
    print("=== building ===")
    subprocess.run(["npm", "run", "build"], cwd=ROOT, check=True)
    subprocess.run(["pm2", "restart", "myframe-api", "--update-env"], check=True)
    print("=== test synthetic heart ===")
    subprocess.run(
        [
            "mosquitto_pub",
            "-h",
            "127.0.0.1",
            "-p",
            "1883",
            "-u",
            "device",
            "-P",
            "framepass2026",
            "-t",
            "/device/report/D0CF13F0161C",
            "-m",
            '{"action":"heart","clientid":"IJ_D0CF13F0161C","data":{"ack":1}}',
            "-q",
            "1",
        ],
        check=False,
    )
    subprocess.run(["curl", "-sS", "http://127.0.0.1:3001/api/frames/D0CF13F0161C/status"], check=False)
    print("\nDone. mqtt_connected should be true after heart publish.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
