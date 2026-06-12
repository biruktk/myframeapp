import 'dart:convert';

import 'vps_defaults.dart';

/// Default MQTT JSON for manual BLE config.
class AppConfig {
  AppConfig._();

  static String get defaultFrameConfig {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert({
      'msgid': DateTime.now().millisecondsSinceEpoch.toString(),
      'action': 'mqtt_config',
      'data': {
        'host': VpsDefaults.host,
        'port': VpsDefaults.mqttPort,
        'usr': VpsDefaults.mqttUser,
        'pwd': VpsDefaults.mqttPass,
      },
    });
  }
}
