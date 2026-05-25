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
    final raw = paired.resolvedFrameTargetId
        .replaceAll(RegExp(r'[^0-9a-fA-F]'), '')
        .toUpperCase();
    if (raw.length < 12) return null;
    return raw.substring(raw.length - 12);
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
}
