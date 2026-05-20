import 'dart:convert';

/// Payload encoded in the frame's pairing QR (`ra/api` + product flow).
/// Example: `{"deviceId":"YX-133P-001","pairingToken":"...","apiUrl":"http://192.168.1.50:8080"}`
class PairingPayload {
  const PairingPayload({
    required this.deviceId,
    this.pairingToken,
    this.apiUrl,
    this.bleServiceUuid,
    this.bleDataCharUuid,
    this.bleNamePrefix,
    this.product,
  });

  final String deviceId;
  final String? pairingToken;

  /// Shipped in QR; when set, must match the app’s configured product line (e.g. `myframe`).
  final String? product;

  /// Base URL for HTTP upload to the frame or hub on the LAN (no trailing slash).
  final String? apiUrl;

  /// Custom BLE GATT UUIDs (see `docs/FRAME_AND_CONNECTIVITY.md`). If null, the app uses built‑in MyFrame defaults.
  final String? bleServiceUuid;
  final String? bleDataCharUuid;

  /// Optional: only connect if advertisement name contains this (e.g. `MyFrame`).
  final String? bleNamePrefix;

  static PairingPayload? tryParse(String raw) {
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        final json = decoded;
        final id = _firstNonEmpty(json, const [
          'deviceId',
          'device_id',
          'deviceID',
          'sn',
          'SN',
          'serial',
          'serialNo',
          'deviceSn',
          'device_sn',
          'id',
        ]);
        if (id == null) return null;
        final ble = json['ble'] is Map ? json['ble'] as Map<String, dynamic> : null;
        return PairingPayload(
          deviceId: id,
          product: (json['product'] as String?)?.trim() ??
              (json['productId'] as String?)?.trim() ??
              (json['brand'] as String?)?.trim(),
          pairingToken: _firstNonEmpty(json, const ['pairingToken', 'pairing_token', 'token']),
          apiUrl: _firstNonEmpty(json, const ['apiUrl', 'api_url', 'server', 'host']),
          bleServiceUuid: _bleStr(json, ble, const [
            'bleService',
            'ble_service',
            'service',
          ]),
          bleDataCharUuid: _bleStr(json, ble, const [
            'bleDataChar',
            'ble_data_char',
            'dataChar',
            'data',
          ]),
          bleNamePrefix: _bleStr(json, ble, const [
            'bleNamePrefix',
            'ble_name_prefix',
            'namePrefix',
          ]),
        );
      }
    } catch (_) {
      // Fall through to URL / key-value parsing.
    }

    final uri = Uri.tryParse(raw.trim());
    if (uri != null && uri.queryParameters.isNotEmpty) {
      final qp = uri.queryParameters;
      final id = _firstNonEmpty(qp, const [
        'deviceId',
        'device_id',
        'sn',
        'serial',
        'serialNo',
        'id',
      ]);
      if (id != null) {
        final api = _firstNonEmpty(qp, const ['apiUrl', 'api_url', 'server']);
        return PairingPayload(
          deviceId: id,
          product: _firstNonEmpty(qp, const ['product', 'productId', 'brand']),
          pairingToken: _firstNonEmpty(qp, const ['pairingToken', 'pairing_token', 'token']),
          apiUrl: api,
        );
      }
    }

    final kv = _parseKeyValue(raw);
    final id = _firstNonEmpty(kv, const [
      'deviceid',
      'device_id',
      'sn',
      'serial',
      'serialno',
      'devicesn',
      'id',
    ]);
    if (id != null) {
      return PairingPayload(
        deviceId: id,
        product: _firstNonEmpty(kv, const ['product', 'productid', 'brand']),
        pairingToken: _firstNonEmpty(kv, const ['pairingtoken', 'pairing_token', 'token']),
        apiUrl: _firstNonEmpty(kv, const ['apiurl', 'api_url', 'server', 'host']),
      );
    }
    return null;
  }

  static String? _firstNonEmpty(Map<dynamic, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final v = map[key];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    return null;
  }

  static Map<String, String> _parseKeyValue(String raw) {
    final out = <String, String>{};
    for (final seg in raw.split(RegExp(r'[;&\n]'))) {
      final i = seg.indexOf('=');
      if (i <= 0) continue;
      final k = seg.substring(0, i).trim().toLowerCase();
      final v = seg.substring(i + 1).trim();
      if (k.isNotEmpty && v.isNotEmpty) out[k] = v;
    }
    return out;
  }

  /// Root JSON (flat) and nested [ble] map, first non-empty value wins.
  static String? _bleStr(
    Map<String, dynamic> root,
    Map<String, dynamic>? ble,
    List<String> keys,
  ) {
    for (final key in keys) {
      final v = root[key] as String? ?? ble?[key] as String?;
      if (v != null && v.trim().isNotEmpty) return v.trim();
    }
    return null;
  }
}
