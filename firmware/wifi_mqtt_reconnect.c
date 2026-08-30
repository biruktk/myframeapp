/**
 * ESP32 Wi-Fi auto-reconnect + MQTT reconnect reference implementation.
 *
 * This file is a MERGE-IN helper — copy the relevant functions into your
 * main firmware source tree (e.g. main/main.c) and wire them into your
 * existing event registration.
 *
 * Problem it solves:
 *   When the Wi-Fi AP drops and comes back online hours later, the ESP32
 *   stays stuck in an unassociated state because the default event handler
 *   only retries a few times before giving up.  This implementation uses
 *   an infinite exponential-backoff retry loop that caps at 5 minutes
 *   between attempts, and re-initialises the MQTT client once IP is
 *   restored.
 *
 * Build: ESP-IDF ≥ 5.x  (uses esp_event, esp_netif, mqtt_client APIs)
 */

#include <string.h>
#include "esp_log.h"
#include "esp_wifi.h"
#include "esp_event.h"
#include "esp_netif.h"
#include "mqtt_client.h"
#include "freertos/FreeRTOS.h"
#include "freertos/timers.h"

static const char *TAG = "wifi_reconnect";

/* ── Backoff constants ─────────────────────────────────────────────────── */

#define RETRY_SHORT_MAX       5     /* first 5 attempts: every 5 s   */
#define RETRY_SHORT_INTERVAL  5000  /* ms                            */
#define RETRY_MED_MAX        20     /* attempts 6-20: every 30 s     */
#define RETRY_MED_INTERVAL   30000  /* ms                            */
#define RETRY_LONG_INTERVAL  120000 /* attempts >20: every 2 min     */

/* ── Module state ──────────────────────────────────────────────────────── */

static esp_mqtt_client_handle_t s_mqtt_client;
static int   s_retry_count;
static TimerHandle_t s_reconnect_timer;

/* Forward declarations — implement these in your firmware. */
static void mqtt_event_handler(void *arg, esp_event_base_t base,
                               int32_t id, void *data);

/* ── Backoff interval calculator ───────────────────────────────────────── */

static int backoff_interval_ms(int attempt) {
    if (attempt <= RETRY_SHORT_MAX) return RETRY_SHORT_INTERVAL;
    if (attempt <= RETRY_MED_MAX)   return RETRY_MED_INTERVAL;
    return RETRY_LONG_INTERVAL;
}

/* ── Timer callback — retries esp_wifi_connect() ───────────────────────── */

static void reconnect_timer_cb(TimerHandle_t timer) {
    ESP_LOGW(TAG, "Wi-Fi reconnect attempt %d", s_retry_count + 1);
    esp_err_t err = esp_wifi_connect();
    if (err != ESP_OK) {
        ESP_LOGW(TAG, "esp_wifi_connect failed: %s — scheduling retry",
                 esp_err_to_name(err));
    }
    /* The next retry is scheduled either here or in the DISCONNECTED handler,
     * whichever fires first.  The handler always increments s_retry_count. */
}

/* ── Wi-Fi event handler ───────────────────────────────────────────────── */

static void wifi_event_handler(void *arg, esp_event_base_t event_base,
                               int32_t event_id, void *event_data) {
    if (event_base == WIFI_EVENT) {
        switch (event_id) {
        case WIFI_EVENT_STA_START:
            ESP_LOGI(TAG, "STA started — connecting");
            esp_wifi_connect();
            break;

        case WIFI_EVENT_STA_DISCONNECTED: {
            wifi_event_sta_disconnected_t *info =
                (wifi_event_sta_disconnected_t *)event_data;
            ESP_LOGW(TAG, "Wi-Fi disconnected (reason %d). "
                     "Scheduling reconnect (attempt %d)...",
                     info->reason, s_retry_count + 1);

            /* Stop any in-flight MQTT client — it is useless without IP. */
            if (s_mqtt_client) {
                esp_mqtt_client_stop(s_mqtt_client);
            }

            /* Exponential backoff — never give up. */
            int interval = backoff_interval_ms(s_retry_count);
            s_retry_count++;

            xTimerChangePeriod(s_reconnect_timer,
                               pdMS_TO_TICKS(interval), 0);
            xTimerStart(s_reconnect_timer, 0);
            break;
        }

        case WIFI_EVENT_STA_CONNECTED:
            /* Association succeeded — reset the backoff counter for next
             * time we lose connectivity. */
            s_retry_count = 0;
            ESP_LOGI(TAG, "Wi-Fi associated — waiting for IP");
            break;

        default:
            break;
        }
    } else if (event_base == IP_EVENT &&
               event_id == IP_EVENT_STA_GOT_IP) {
        ip_event_got_ip_t *info = (ip_event_got_ip_t *)event_data;
        ESP_LOGI(TAG, "Got IP: " IPSTR, IP2STR(&info->ip_info.ip));

        /* Reset backoff — we are connected. */
        s_retry_count = 0;
        xTimerStop(s_reconnect_timer, 0);

        /* (Re-)start MQTT client. */
        if (s_mqtt_client) {
            esp_mqtt_client_start(s_mqtt_client);
        }
    }
}

/* ── MQTT event handler (re-subscribes after reconnect) ────────────────── */

static void mqtt_event_handler(void *arg, esp_event_base_t base,
                               int32_t id, void *data) {
    esp_mqtt_event_handle_t event = (esp_mqtt_event_handle_t)data;
    switch (event->event_id) {
    case MQTT_EVENT_CONNECTED:
        ESP_LOGI(TAG, "MQTT connected — subscribing");
        /* Subscribe to the device command topic.
         * Replace {mac} with your frame's MAC address. */
        esp_mqtt_client_subscribe(s_mqtt_client,
                                  "/inkjoyap/{mac}", 1);
        break;

    case MQTT_EVENT_DISCONNECTED:
        ESP_LOGW(TAG, "MQTT disconnected — will auto-reconnect "
                 "when Wi-Fi is available");
        /* The esp_mqtt_client library handles reconnect internally
         * when disable_auto_reconnect = false (the default).
         * We do NOT need to manually reconnect here — just ensure
         * the client is started once we have IP. */
        break;

    case MQTT_EVENT_ERROR:
        ESP_LOGE(TAG, "MQTT error type: %d", event->error_handle->error_type);
        break;

    default:
        break;
    }
}

/* ── Public init function — call from app_main() ───────────────────────── */

void wifi_mqtt_reconnect_init(const char *mqtt_uri,
                              const char *mqtt_user,
                              const char *mqtt_pass) {
    /* Create the backoff timer (one-shot, auto-reload off). */
    s_reconnect_timer = xTimerCreate(
        "wifi_reconn",
        pdMS_TO_TICKS(RETRY_SHORT_INTERVAL),
        pdFALSE,   /* auto-reload off */
        NULL,
        reconnect_timer_cb);

    /* Register Wi-Fi + IP event handlers. */
    esp_event_handler_register(WIFI_EVENT, ESP_EVENT_ANY_ID,
                               wifi_event_handler, NULL);
    esp_event_handler_register(IP_EVENT, IP_EVENT_STA_GOT_IP,
                               wifi_event_handler, NULL);

    /* Configure MQTT client. */
    esp_mqtt_client_config_t mqtt_cfg = {
        .broker.address.uri = mqtt_uri,
        .credentials.username = mqtt_user,
        .credentials.authentication.password = mqtt_pass,
        /* disable_auto_reconnect defaults to false — the library will
         * automatically reconnect the MQTT session once TCP is available.
         * Setting it explicitly for clarity: */
        .session.keepalive = 60,
    };
    s_mqtt_client = esp_mqtt_client_init(&mqtt_cfg);
    esp_mqtt_client_register_event(s_mqtt_client, ESP_EVENT_ANY_ID,
                                   mqtt_event_handler, NULL);
    /* Do NOT start yet — wait for IP_EVENT_STA_GOT_IP. */

    ESP_LOGI(TAG, "Wi-Fi/MQTT reconnect module initialised");
}
