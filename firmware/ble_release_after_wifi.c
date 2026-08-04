/**
 * MyFrame ESP32 — release BLE after Wi‑Fi STA gets an IP.
 *
 * There is no firmware source tree in this workspace (only a flashed .bin).
 * Merge this handler into your BluFi / wifi_prov GATT app so WeChat / Flutter
 * cannot leave the frame locked on a stale GATT connection.
 *
 * Hook points (ESP-IDF BluFi or custom GATT):
 *  - SYSTEM_EVENT_STA_GOT_IP / WIFI_EVENT_STA_GOT_IP / IP_EVENT_STA_GOT_IP
 *  - After successful BluFi Wi‑Fi report to the phone
 */

#include "esp_log.h"
#include "esp_gap_ble_api.h"
#include "esp_gatts_api.h"
#include "esp_wifi.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"

static const char *TAG = "myframe_ble_release";

/* Set by your GATTS connect callback. */
static uint16_t s_conn_id = 0xFFFF;
static esp_gatt_if_t s_gatts_if = ESP_GATT_IF_NONE;
static bool s_connected = false;

void myframe_ble_on_gatts_connect(esp_gatt_if_t gatts_if, uint16_t conn_id)
{
    s_gatts_if = gatts_if;
    s_conn_id = conn_id;
    s_connected = true;
    ESP_LOGI(TAG, "GATT connected if=%d conn=%u", (int)gatts_if, (unsigned)conn_id);
}

void myframe_ble_on_gatts_disconnect(void)
{
    s_connected = false;
    s_conn_id = 0xFFFF;
    ESP_LOGI(TAG, "GATT disconnected");
}

/** Close the active central and stop advertising until setup mode is re-entered. */
void myframe_ble_release_after_wifi(void)
{
    if (s_connected && s_gatts_if != ESP_GATT_IF_NONE && s_conn_id != 0xFFFF) {
        ESP_LOGI(TAG, "Closing GATT after STA_GOT_IP (conn=%u)", (unsigned)s_conn_id);
        esp_ble_gatts_close(s_gatts_if, s_conn_id);
        s_connected = false;
    }

    /* Prefer stopping BluFi / wifi_prov manager if you use Espressif provisioning: */
#if defined(CONFIG_BT_BLUFI_ENABLE) || defined(MYFRAME_USE_WIFI_PROV)
    /* wifi_prov_mgr_stop_provisioning(); */
    /* esp_blufi_profile_deinit();  // only if your stack allows clean re-init */
#endif

    esp_ble_gap_stop_advertising();
    ESP_LOGI(TAG, "BLE advertising stopped — re-enable only in setup mode");
}

/**
 * Example IP event wiring (ESP-IDF v4/v5):
 *
 * static void on_ip(void *arg, esp_event_base_t base, int32_t id, void *data)
 * {
 *     if (base == IP_EVENT && id == IP_EVENT_STA_GOT_IP) {
 *         // Give the phone ~1s to receive the BluFi STA connected report.
 *         vTaskDelay(pdMS_TO_TICKS(1000));
 *         myframe_ble_release_after_wifi();
 *     }
 * }
 * ESP_ERROR_CHECK(esp_event_handler_register(IP_EVENT, IP_EVENT_STA_GOT_IP, &on_ip, NULL));
 *
 * Also call myframe_ble_release_after_wifi() from your BluFi
 * ESP_BLUFI_EVENT_RECV_STA_SSID / password success path after you notify
 * the phone, so a phone that never disconnects still frees the radio.
 */
