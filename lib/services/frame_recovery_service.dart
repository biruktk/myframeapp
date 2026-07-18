import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/vps_defaults.dart';
import 'ble_frame_device_transport.dart';
import 'blufi_provisioning_service.dart';
import 'device_store.dart';

class FrameRecoveryService {
  FrameRecoveryService._();

  static final FrameRecoveryService instance = FrameRecoveryService._();

  String? pairedFrameMac(PairedFrame paired) {
    final stored = DeviceStore.instance.pairedFrameMac;
    if (stored != null && stored.length == 12) return stored;
    final raw = paired.deviceId
        .replaceAll(RegExp(r'[^0-9a-fA-F]'), '')
        .toUpperCase();
    if (raw.length >= 12) return raw.substring(raw.length - 12);
    return null;
  }

  Future<String> reconfigureServer(PairedFrame paired) async {
    await DeviceStore.instance.saveSelfHostedMqtt(
      host: VpsDefaults.host,
      port: VpsDefaults.mqttPort,
      user: VpsDefaults.mqttUser,
      password: VpsDefaults.mqttPass,
    );
    await BleFrameDeviceTransport.instance.releaseSession();
    final result = await BlufiProvisioningService.instance.reconfigureServer(
      paired: paired,
      selfHostedMqtt: const SelfHostedMqttConfig(
        host: VpsDefaults.host,
        port: VpsDefaults.mqttPort,
        user: VpsDefaults.mqttUser,
        password: VpsDefaults.mqttPass,
      ),
    );
    if (!result.ok) throw StateError(result.message);
    return result.message;
  }

  /// Wake MQTT session before cloud upload (retained mqtt_config + login_ack, like WeChat).
  Future<void> prepareForCloudUpload(PairedFrame paired) async {
    await BleFrameDeviceTransport.instance.releaseSession();
    Object? lastErr;
    for (var i = 0; i < 2; i++) {
      try {
        await wakeFrameMqtt(paired);
        await Future<void>.delayed(const Duration(milliseconds: 1200));
        return;
      } catch (e) {
        lastErr = e;
        await Future<void>.delayed(const Duration(milliseconds: 400));
      }
    }
    if (lastErr != null) throw lastErr;
  }

  Future<void> wakeFrameMqtt(PairedFrame paired) async {
    // NEVER send mqtt_config during send flow - it overwrites retained play command!
    // mqtt_config is sent ONLY during BLE pairing (matches mini app behavior)
    await sendLoginAck(paired);
  }

  Future<void> sendMqttBrokerConfig(PairedFrame paired) async {
    final mac = pairedFrameMac(paired);
    if (mac == null) {
      throw StateError('Paired frame MAC is unavailable. Re-scan the frame first.');
    }
    final base = paired.resolvedApiBaseUrl ?? VpsDefaults.apiBase;
    final token = paired.resolvedPairingToken;
    final uri = Uri.parse('$base/api/frames/$mac/mqtt-config');
    final res = await http
        .post(
          uri,
          headers: {
            'content-type': 'application/json',
            'accept': 'application/json',
            if ((token ?? '').isNotEmpty) 'x-pairing-token': token!,
          },
          body: jsonEncode({'msgid': DateTime.now().millisecondsSinceEpoch.toString()}),
        )
        .timeout(const Duration(seconds: 12));
    final data = (res.body.isEmpty ? const <String, dynamic>{} : jsonDecode(res.body) as Map<String, dynamic>);
    final success = res.statusCode >= 200 && res.statusCode < 300 && data['ok'] == true;
    if (!success) {
      throw StateError((data['error'] ?? data['message'] ?? 'mqtt_config failed').toString());
    }
  }

  Future<String> sendLoginAck(PairedFrame paired) async {
    final mac = pairedFrameMac(paired);
    if (mac == null) {
      throw StateError('Paired frame MAC is unavailable. Re-scan the frame first.');
    }
    final base = paired.resolvedApiBaseUrl ?? VpsDefaults.apiBase;
    final token = paired.resolvedPairingToken;
    final uri = Uri.parse('$base/api/frames/$mac/login-ack');
    final res = await http
        .post(
          uri,
          headers: {
            'content-type': 'application/json',
            'accept': 'application/json',
            if ((token ?? '').isNotEmpty) 'x-pairing-token': token!,
          },
          body: jsonEncode({
            'msgid': DateTime.now().millisecondsSinceEpoch.toString(),
            'stamac': mac,
          }),
        )
        .timeout(const Duration(seconds: 12));
    final data = (res.body.isEmpty ? const <String, dynamic>{} : jsonDecode(res.body) as Map<String, dynamic>);
    final success = res.statusCode >= 200 && res.statusCode < 300 && data['ok'] == true;
    if (!success) {
      throw StateError((data['error'] ?? data['message'] ?? 'login_ack failed').toString());
    }
    return 'login_ack sent to $mac';
  }

  /// HTTP republish fallback — wake MQTT then re-publish play command.
  /// Used when MQTT delivery fails or frame doesn't confirm.
  /// Matches WeChat mini app's `burstDeliverPlay()` function.
  Future<String> republishPlayWithWake(
    PairedFrame paired,
    String imageUrl,
  ) async {
    // Wake MQTT first
    await sendLoginAck(paired);
    await Future<void>.delayed(const Duration(milliseconds: 400));

    // Republish play command
    final mac = pairedFrameMac(paired);
    if (mac == null) {
      throw StateError('Paired frame MAC is unavailable. Re-scan the frame first.');
    }
    final base = paired.resolvedApiBaseUrl ?? VpsDefaults.apiBase;
    final token = paired.resolvedPairingToken;
    final uri = Uri.parse('$base/api/device/send');
    final res = await http
        .post(
          uri,
          headers: {
            'content-type': 'application/json',
            'accept': 'application/json',
            if ((token ?? '').isNotEmpty) 'x-pairing-token': token!,
          },
          body: jsonEncode({
            'device_id': mac,
            'image_url': imageUrl,
          }),
        )
        .timeout(const Duration(seconds: 12));
    final data = (res.body.isEmpty ? const <String, dynamic>{} : jsonDecode(res.body) as Map<String, dynamic>);
    final success = res.statusCode >= 200 && res.statusCode < 300 && data['ok'] == true;
    if (!success) {
      throw StateError((data['error'] ?? data['message'] ?? 'republish failed').toString());
    }
    return 'Play command republished to $mac';
  }
}
