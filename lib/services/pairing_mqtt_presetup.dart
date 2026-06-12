import '../config/vps_defaults.dart';
import 'blufi_provisioning_service.dart';
import 'device_store.dart';

/// EspBlufi order: push `mqtt_config` over BLE **before** the Wi‑Fi provision screen.
class PairingMqttPresetup {
  PairingMqttPresetup._();

  static const _defaultMqtt = SelfHostedMqttConfig(
    host: VpsDefaults.host,
    port: VpsDefaults.mqttPort,
    user: VpsDefaults.mqttUser,
    password: VpsDefaults.mqttPass,
  );

  /// Persists VPS broker defaults and sends mqtt_config JSON to the frame over BLE.
  /// Returns whether the frame acknowledged the config write.
  static Future<bool> sendDefaultBrokerBeforeWifi() async {
    final store = DeviceStore.instance;
    await store.saveSelfHostedMqtt(
      host: VpsDefaults.host,
      port: VpsDefaults.mqttPort,
      user: VpsDefaults.mqttUser,
      password: VpsDefaults.mqttPass,
    );
    final paired = store.cached;
    if (paired == null) return false;
    final result = await BlufiProvisioningService.instance.reconfigureServer(
      paired: paired,
      selfHostedMqtt: _defaultMqtt,
    );
    return result.ok;
  }
}
