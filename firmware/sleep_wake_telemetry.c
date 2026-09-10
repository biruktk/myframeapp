/**
 * ESP32 MyFrame — Sleep wake-on-command + live telemetry reference.
 *
 * This file is a MERGE-IN helper (like wifi_mqtt_reconnect.c). Copy the
 * relevant functions into your main source tree and wire them into your MQTT
 * payload parser. It implements:
 *
 *   1. Handling the server's wake / `update_config` command so toggling sleep
 *      OFF immediately wakes the frame, powers the modem rails, re-samples
 *      hardware, and publishes a fresh `report`.
 *   2. A `report` publisher carrying accurate battery (with ADC calibration),
 *      charging state, SD-card mount/capacity (statvfs), and Wi-Fi RSSI — the
 *      exact fields the backend parses into `myframe-db.json`.
 *
 * BUILD: ESP-IDF ≥ 5.x (esp_wifi, esp_event, esp_netif, mqtt_client,
 *        driver/adc, "esp_vfs_fat", "sys/statvfs").
 *
 * Wire-up: call `myframe_mqtt_on_payload(topic, payload, len)` from your MQTT
 *          `MQTT_EVENT_DATA` handler, and `myframe_report_telemetry()` after
 *          Wi-Fi/IP is restored (IP_EVENT_STA_GOT_IP) or after a wake.
 */

#include <string.h>
#include <inttypes.h>
#include <sys/statvfs.h>
#include "esp_log.h"
#include "esp_wifi.h"
#include "esp_netif.h"
#include "esp_adc/adc_oneshot.h"
#include "esp_vfs_fat.h"
#include "mqtt_client.h"

static const char *TAG = "myframe_telemetry";

/* ── Set by your app (same client used in wifi_mqtt_reconnect.c) ──────── */
extern esp_mqtt_client_handle_t s_mqtt_client;

/* ── App callbacks — implement in your power/sleep module ─────────────── */
extern void myframe_cancel_deep_sleep(void);
extern void myframe_power_on_peripherals(void);
extern bool myframe_is_sleeping(void);

/* ── Hardware sampling helpers ────────────────────────────────────────── */
static int adc_battery_percent(void) {
  /* Replace with your calibrated mapping (ADC → Li-ion %). This is a
   * placeholder: read the battery divider, apply a lookup table / linear
   * fit, clamp 0..100. */
  int percent = adc_battery_raw_to_calibrated_percent();
  if (percent < 0) percent = 0;
  if (percent > 100) percent = 100;
  return percent;
}

static bool battery_is_charging(void) {
  /* Read the charge-detect GPIO / PMIC status. */
  return charge_gpio_is_high();
}

static bool sd_mounted(void) {
  return sdmmc_check_mount_state();
}

static void sd_capacity_mb(uint64_t *total_mb, uint64_t *free_mb) {
  struct statvfs st;
  if (statvfs("/sdcard", &st) != 0) {
    *total_mb = 0;
    *free_mb = 0;
    return;
  }
  uint64_t block = st.f_bsize;
  *total_mb = (uint64_t)st.f_blocks * block / (1024u * 1024u);
  *free_mb  = (uint64_t)st.f_bavail * block / (1024u * 1024u);
}

/* ── Telemetry payload builder + publisher ────────────────────────────── */
void myframe_report_telemetry(const char *client_id) {
  if (!s_mqtt_client) return;

  uint64_t total_mb = 0, free_mb = 0;
  sd_capacity_mb(&total_mb, &free_mb);

  int8_t rssi = 0;
  wifi_ap_record_t apt;
  if (esp_wifi_sta_get_ap_info(&apt) == ESP_OK) rssi = apt.rssi;

  char payload[512];
  snprintf(payload, sizeof(payload),
    "{\"action\":\"report\",\"clientId\":\"%s\","
    "\"battery\":%d,\"is_charging\":%s,"
    "\"sd_card\":{\"mounted\":%s,\"total_mb\":%" PRIu64 ",\"free_mb\":%" PRIu64 "},"
    "\"wifi_rssi\":%d}",
    client_id,
    adc_battery_percent(),
    battery_is_charging() ? "true" : "false",
    sd_mounted() ? "true" : "false",
    total_mb, free_mb,
    rssi);

  char topic[64];
  snprintf(topic, sizeof(topic), "/device/report/%s", client_id);
  int msg_id = esp_mqtt_client_publish(s_mqtt_client, topic, payload, 0, 1, 0);
  ESP_LOGI(TAG, "report published (id=%d): %s", msg_id, payload);
}

/* ── Wake / update_config command handler ──────────────────────────────── */
bool myframe_handle_wake_command(const char *payload_json) {
  /* Expect the server's update_config command:
   *   { "action":"update_config", "sleep_enabled":false, "force_wake":true,
   *     "request_telemetry":true }
   * Also accept a bare "wake" action (immediate wake relay). */
  if (!payload_json) return false;

  bool force_wake = strstr(payload_json, "\"force_wake\":true") != NULL;
  bool sleep_disabled = strstr(payload_json, "\"sleep_enabled\":false") != NULL;
  bool req_telemetry = strstr(payload_json, "\"request_telemetry\":true") != NULL;
  bool is_wake_action = strstr(payload_json, "\"action\":\"wake\"") != NULL;

  if (!(force_wake || sleep_disabled || is_wake_action)) return false;

  ESP_LOGI(TAG, "wake command received — cancelling deep sleep");

  /* 1. Wake up / stay awake until explicitly re-enabled. */
  myframe_cancel_deep_sleep();
  myframe_power_on_peripherals();

  /* 2. Re-sync MQTT if WiFi/IP is up, then publish fresh telemetry now. */
  if (req_telemetry && s_mqtt_client) {
    const char *client_id = myframe_station_mac();
    myframe_report_telemetry(client_id);
  }
  return true;
}

/* ── WiFi / IP restore hook: publish an online heart + report ─────────── */

void myframe_on_network_restored(const char *client_id) {
  ESP_LOGI(TAG, "network restored — publishing heart + report");
  if (!s_mqtt_client) return;

  char heart[128];
  snprintf(heart, sizeof(heart),
    "{\"action\":\"heart\",\"clientId\":\"%s\",\"status\":\"online\"}", client_id);
  char topic[64];
  snprintf(topic, sizeof(topic), "/device/report/%s", client_id);
  esp_mqtt_client_publish(s_mqtt_client, topic, heart, 0, 1, 0);

  myframe_report_telemetry(client_id);
}

/* Convenience helpers you must implement (see your hardware layer). */
extern int adc_battery_raw_to_calibrated_percent(void);
extern bool charge_gpio_is_high(void);
extern bool sdmmc_check_mount_state(void);
extern const char *myframe_station_mac(void);
