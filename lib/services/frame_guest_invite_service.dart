import 'dart:convert';

import '../config/api_config.dart';
import '../config/vps_defaults.dart';
import 'api_client.dart';
import 'app_diag_log.dart';
import 'device_store.dart';

class FrameGuestInvite {
  const FrameGuestInvite({
    required this.inviteCode,
    required this.inviteUrl,
    required this.deviceId,
  });

  final String inviteCode;
  final String inviteUrl;
  final String deviceId;
}

/// Guest upload link for ShareLink — friends open `/invite/:code` to send photos.
class FrameGuestInviteService {
  FrameGuestInviteService._();

  static final FrameGuestInviteService instance = FrameGuestInviteService._();

  final _api = ApiClient();

  /// Resolves 12-hex frame MAC for invite API from paired frame.
  String? deviceIdForInvite(PairedFrame frame) {
    final mac = DeviceStore.instance.pairedFrameMac;
    if (mac != null && mac.length == 12) return mac;
    final slug = frame.resolvedFrameTargetId.trim();
    if (slug.isEmpty) return null;
    final bare = slug.replaceAll(RegExp(r'[^0-9a-fA-F]'), '').toUpperCase();
    if (bare.length >= 12) return bare.substring(bare.length - 12);
    return bare.length >= 6 ? bare : null;
  }

  Future<FrameGuestInvite?> createOrFetchInvite({
    required PairedFrame frame,
    String? userAuthToken,
  }) async {
    final deviceId = deviceIdForInvite(frame);
    if (deviceId == null || deviceId.isEmpty) {
      AppDiagLog.log('[ShareLink] no device id for invite');
      return null;
    }

    final token = userAuthToken?.trim() ?? '';
    if (token.isNotEmpty) {
      final viaPost = await _postFrameInvite(deviceId, token);
      if (viaPost != null) return viaPost;
    }

    return _getGenerateInvite(deviceId, userAuthToken: token.isEmpty ? null : token);
  }

  Future<FrameGuestInvite?> _postFrameInvite(String deviceId, String token) async {
    final bases = [
      ApiConfig.baseUrl.replaceAll(RegExp(r'/+$'), ''),
      VpsDefaults.apiBase,
    ];
    for (final base in bases.toSet()) {
      try {
        final res = await _api
            .post(
              Uri.parse('$base/api/frame/invite'),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                'Authorization': 'Bearer $token',
              },
              body: jsonEncode({'deviceId': deviceId}),
            )
            .timeout(const Duration(seconds: 15));
        if (res.statusCode < 200 || res.statusCode >= 300) {
          AppDiagLog.log('[ShareLink] POST frame/invite ${res.statusCode} ${res.body}');
          continue;
        }
        return _parseInviteJson(jsonDecode(res.body) as Map<String, dynamic>, deviceId);
      } catch (e) {
        AppDiagLog.log('[ShareLink] POST frame/invite failed: $e');
      }
    }
    return null;
  }

  Future<FrameGuestInvite?> _getGenerateInvite(
    String deviceId, {
    String? userAuthToken,
  }) async {
    final bases = [
      ApiConfig.baseUrl.replaceAll(RegExp(r'/+$'), ''),
      VpsDefaults.apiBase,
    ];
    for (final base in bases.toSet()) {
      try {
        final uri = Uri.parse('$base/api/invite/generate').replace(
          queryParameters: {'frameMac': deviceId},
        );
        final headers = <String, String>{'Accept': 'application/json'};
        final token = userAuthToken?.trim();
        if (token != null && token.isNotEmpty) {
          headers['Authorization'] = 'Bearer $token';
        }
        final res = await _api.get(uri, headers: headers).timeout(const Duration(seconds: 15));
        if (res.statusCode < 200 || res.statusCode >= 300) {
          AppDiagLog.log('[ShareLink] GET invite/generate ${res.statusCode} ${res.body}');
          continue;
        }
        return _parseInviteJson(jsonDecode(res.body) as Map<String, dynamic>, deviceId);
      } catch (e) {
        AppDiagLog.log('[ShareLink] GET invite/generate failed: $e');
      }
    }
    return null;
  }

  FrameGuestInvite? _parseInviteJson(Map<String, dynamic> json, String deviceId) {
    if (json['ok'] != true && json['success'] != true) return null;
    final code = (json['inviteCode'] ?? json['code'])?.toString().trim() ?? '';
    final url = (json['inviteUrl'] ?? json['url'] ?? json['link'])?.toString().trim() ?? '';
    if (code.isEmpty || url.isEmpty) return null;
    return FrameGuestInvite(inviteCode: code, inviteUrl: url, deviceId: deviceId);
  }
}
