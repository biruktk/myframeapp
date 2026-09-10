# MyFrame Firmware Reference Snippets

This folder contains **reference C snippets** from the ESP32-C5 firmware — NOT a
buildable ESP-IDF project. Copy the relevant functions into your real firmware
source tree (`main/` components) and wire them into your event handlers.

| File | Purpose |
|------|---------|
| `wifi_mqtt_reconnect.c` | Infinite Wi-Fi reconnect with exponential backoff + MQTT re-init on IP. |
| `sleep_wake_telemetry.c` | Wake-on-`update_config`/`force_wake` + fresh `report` telemetry (battery/charging/SD-card/RSSI). |
| `ble_release_after_wifi.c` | Release BLE after Wi-Fi is up. |
| `playback_random_index.c` | Random playlist index selection. |

## Requirement mapping

### 1. Immediate wake-up on sleep toggle-OFF
The backend publishes `update_config { sleep_enabled:false, force_wake:true,
request_telemetry:true }` to `/myframe/{MAC}` (via `frame_sleep.ts`) when the
user toggles sleep OFF. On the device:

- Parse `force_wake:true` / `sleep_enabled:false` (see
  `myframe_handle_wake_command` in `sleep_wake_telemetry.c`).
- `myframe_cancel_deep_sleep()` — cancel any pending deep-sleep timer.
- `myframe_power_on_peripherals()` — re-apply power rails for the modem/panel.
- Call `myframe_report_telemetry(client_id)` immediately so the server gets the
  fresh battery/SD-card/RSSI **without** waiting for the next 10-min heart.
- Sample with calibrated ADC (`adc_battery_percent`), charging GPIO
  (`battery_is_charging`), `statvfs("/sdcard")` (`sd_capacity_mb`), and
  `esp_wifi_sta_get_ap_info` (RSSI).

### 2. Persistent Wi-Fi auto-reconnect
`wifi_mqtt_reconnect.c` already implements the required behaviour:

- `WIFI_EVENT_STA_DISCONNECTED` → do NOT stop Wi-Fi; schedule
  `esp_wifi_connect()` with backoff (`backoff_interval_ms`: 5s → 30s → 2m,
  capped, never give up).
- `IP_EVENT_STA_GOT_IP` → reset backoff, restart MQTT, re-subscribe.
- Extend `IP_EVENT_STA_GOT_IP` to call `myframe_on_network_restored(client_id)`:
  it publishes an online `heart` + a `report` so the backend flips the frame to
  "Online" immediately (the backend's `heart`/`report` handler updates
  `lastSeenAtMs` → `frameStatusPayload` reports `status: "online"`).

## Onboarding the telemetry parser (backend)
The backend `frame_mqtt.ts` now parses `report` and `heart` payloads and writes
`battery`, `is_charging`, `sd_card {mounted,total_mb,free_mb}`, and `rssi` to the
frame row in `myframe-db.json`; `frame_pairing.ts` exposes them as
`is_charging`, `sd_card`, `sdcard_mounted/total/free`, `wifi_rssi`,
`wifi_signal_dbm`. Publish the fields exactly as shown in `sleep_wake_telemetry.c`
so the clients show accurate values.
