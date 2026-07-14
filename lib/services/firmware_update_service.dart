import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';

class FirmwareCheckResponse {
  const FirmwareCheckResponse({
    required this.deviceId,
    required this.currentVersion,
    required this.latestVersion,
    required this.updateAvailable,
    required this.releaseNotes,
    required this.sizeBytes,
    required this.otaStatus,
    required this.otaTargetVersion,
    required this.frameOnline,
    required this.mqttConnected,
  });

  final String deviceId;
  final String currentVersion;
  final String latestVersion;
  final bool updateAvailable;
  final String releaseNotes;
  final int sizeBytes;
  final String otaStatus;
  final String? otaTargetVersion;
  final bool frameOnline;
  final bool mqttConnected;

  factory FirmwareCheckResponse.fromJson(Map<String, dynamic> json) {
    return FirmwareCheckResponse(
      deviceId: '${json['deviceId'] ?? ''}',
      currentVersion: '${json['currentVersion'] ?? '0.0.0'}',
      latestVersion: '${json['latestVersion'] ?? '0.0.0'}',
      updateAvailable: json['updateAvailable'] == true,
      releaseNotes: '${json['releaseNotes'] ?? ''}',
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
      otaStatus: '${json['otaStatus'] ?? 'idle'}',
      otaTargetVersion: json['otaTargetVersion']?.toString(),
      frameOnline: json['frameOnline'] == true,
      mqttConnected: json['mqttConnected'] == true,
    );
  }

  bool get isUpdating => otaStatus == 'updating' || otaStatus == 'queued';
  bool get isSuccess => otaStatus == 'success';
  bool get isFailed => otaStatus == 'failed';
}

class FirmwareUpdateResult {
  const FirmwareUpdateResult({required this.ok, this.targetVersion, this.downloadUrl, this.error, this.message});

  final bool ok;
  final String? targetVersion;
  final String? downloadUrl;
  final String? error;
  final String? message;

  factory FirmwareUpdateResult.fromJson(Map<String, dynamic> json) {
    return FirmwareUpdateResult(
      ok: json['ok'] == true,
      targetVersion: json['targetVersion']?.toString(),
      downloadUrl: json['downloadUrl']?.toString(),
      error: json['error']?.toString(),
      message: json['message']?.toString(),
    );
  }
}

class FirmwareUpdateService {
  FirmwareUpdateService({String? baseUrl}) : _origin = (baseUrl ?? ApiConfig.baseUrl).replaceAll(RegExp(r'/+$'), '');

  final String _origin;

  Map<String, String> _headers(String bearerToken) => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (bearerToken.trim().isNotEmpty) 'Authorization': 'Bearer ${bearerToken.trim()}',
      };

  Future<FirmwareCheckResponse> checkUpdate({
    required String deviceId,
    required String bearerToken,
    String? bleMac,
    String? displayName,
  }) async {
    await ensureFrameLinked(
      deviceId: deviceId,
      bearerToken: bearerToken,
      bleMac: bleMac,
      displayName: displayName,
    );
    final uri = Uri.parse('$_origin/api/user/firmware/check').replace(queryParameters: {'deviceId': deviceId});
    final res = await http.get(uri, headers: _headers(bearerToken)).timeout(const Duration(seconds: 20));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 || body['ok'] == false) {
      throw FirmwareUpdateException(body['error']?.toString() ?? 'check_failed', res.statusCode);
    }
    return FirmwareCheckResponse.fromJson(body);
  }

  Future<FirmwareUpdateResult> installUpdate({
    required String deviceId,
    required String bearerToken,
    String? bleMac,
    String? displayName,
  }) async {
    await ensureFrameLinked(
      deviceId: deviceId,
      bearerToken: bearerToken,
      bleMac: bleMac,
      displayName: displayName,
    );
    final uri = Uri.parse('$_origin/api/user/firmware/update');
    final res = await http
        .post(
          uri,
          headers: _headers(bearerToken),
          body: jsonEncode({'deviceId': deviceId}),
        )
        .timeout(const Duration(seconds: 45));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode < 200 || res.statusCode >= 300) {
      return FirmwareUpdateResult.fromJson(body);
    }
    return FirmwareUpdateResult.fromJson(body);
  }

  /// Links the paired frame to the signed-in user so firmware APIs can resolve it.
  Future<void> ensureFrameLinked({
    required String deviceId,
    required String bearerToken,
    String? bleMac,
    String? displayName,
  }) async {
    if (deviceId.trim().isEmpty || bearerToken.trim().isEmpty) return;
    final uri = Uri.parse('$_origin/api/user/devices');
    final body = <String, dynamic>{
      'deviceId': deviceId.trim(),
      if (bleMac != null && bleMac.trim().isNotEmpty) 'bleMac': bleMac.trim(),
      if (displayName != null && displayName.trim().isNotEmpty) 'displayName': displayName.trim(),
    };
    final res = await http
        .post(uri, headers: _headers(bearerToken), body: jsonEncode(body))
        .timeout(const Duration(seconds: 20));
    if (res.statusCode == 401) {
      throw FirmwareUpdateException('unauthorized', res.statusCode);
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final map = jsonDecode(res.body);
      final err = map is Map ? map['error']?.toString() ?? 'link_failed' : 'link_failed';
      throw FirmwareUpdateException(err, res.statusCode);
    }
  }
}

class FirmwareUpdateException implements Exception {
  FirmwareUpdateException(this.code, this.statusCode);
  final String code;
  final int statusCode;

  @override
  String toString() => 'FirmwareUpdateException($code, $statusCode)';
}
