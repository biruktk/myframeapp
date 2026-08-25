import 'dart:convert';

import 'protocol_logger_service.dart';

import '../config/api_config.dart';
import 'api_client.dart';

class SlideshowRemoteApi {
  SlideshowRemoteApi({String? baseUrl})
      : _origin = (baseUrl ?? ApiConfig.baseUrl).replaceAll(RegExp(r'/+$'), '');

  final String _origin;

  Future<void> publish({
    String? bearerToken,
    String? pairingToken,
    required String macSlug,
    required List<String> imageIds,
    required int intervalMinutes,
    int strategy = 1,
    int durationHours = 0,
    bool skipPlay = false,
    /// Explicit unit for `intervalMinutes`. 'minute' (default) or 'second'.
    String intervalUnit = 'minute',
    /// Explicit seconds override. When set (>0), takes precedence over
    /// `intervalMinutes` and forces intervalUnit='second'.
    int? intervalSeconds,
    /// When true (or when skipPlay=false), the backend fires an immediate
    /// MQTT `play` command so the device renders the first photo right after
    /// the strategy_bin dispatch instead of waiting for the first interval tick.
    bool immediatePlay = true,
  }) async {
    if (imageIds.isEmpty) return;
    final encoded = Uri.encodeComponent(macSlug);
    final uri = Uri.parse('$_origin/api/frames/$encoded/slideshow');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final bt = bearerToken?.trim() ?? '';
    final pt = pairingToken?.trim() ?? '';
    if (pt.isNotEmpty) {
      headers['x-pairing-token'] = pt;
    }
    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;

    // Interval unit normalisation: prefer `intervalSeconds` (seconds) when
    // provided; otherwise fall back to `intervalMinutes` with explicit unit.
    int finalIntervalMinutes = intervalMinutes;
    String finalIntervalUnit = intervalUnit;
    if (intervalSeconds != null && intervalSeconds > 0) {
      finalIntervalMinutes = (intervalSeconds / 60).ceil();
      finalIntervalUnit = 'second';
    }
    if (finalIntervalMinutes < 1) finalIntervalMinutes = 1;

    final body = <String, dynamic>{
      'imageIds': imageIds,
      'intervalMinutes': finalIntervalMinutes,
      'intervalUnit': finalIntervalUnit,
      'strategy': strategy,
      'begintime': nowMs.toString(),
      'endtime': durationHours > 0 ? (nowMs + durationHours * 3600 * 1000).toString() : '',
      'idle': 1,
      // Immediate first-photo push: the backend fires an MQTT `play` command
      // for `imageIds[0]` immediately after `strategy_bin`. Default ON so the
      // device displays the first new photo right away.
      'immediatePlay': immediatePlay,
    };
    if (skipPlay) body['skipPlay'] = true;
    final res = await ApiClient(bearerToken: bt).post(
      uri,
      headers: headers,
      body: jsonEncode(body),
    );
    ProtocolLoggerService.instance.logMqttOut('strategy_bin', body);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw SlideshowPublishException(res.statusCode, res.body);
    }
  }

  /// Clear frame slideshow, MQTT stop, play last single / connected fallback.
  Future<bool> stopPlaylist({
    String? bearerToken,
    String? pairingToken,
    required String macSlug,
    List<String> excludeImageIds = const [],
  }) async {
    ProtocolLoggerService.instance.logMqttOut('strategy_stop', {'mac': macSlug, 'excludeImageIds': excludeImageIds});
    final slug = macSlug.trim();
    if (slug.isEmpty) return false;
    final encoded = Uri.encodeComponent(slug);
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final bt = bearerToken?.trim() ?? '';
    final pt = pairingToken?.trim() ?? '';
    if (pt.isNotEmpty) {
      headers['x-pairing-token'] = pt;
    }
    final api = ApiClient(bearerToken: bt);

    Future<bool> tryPost() async {
      final uri = Uri.parse('$_origin/api/frames/$encoded/stop-playlist');
      final res = await api
          .post(
            uri,
            headers: headers,
            body: jsonEncode({'excludeImageIds': excludeImageIds}),
          )
          .timeout(const Duration(seconds: 20));
      return res.statusCode >= 200 && res.statusCode < 300;
    }

    Future<bool> tryDelete() async {
      final uri = Uri.parse('$_origin/api/frames/$encoded/slideshow');
      final res = await api
          .delete(uri, headers: headers)
          .timeout(const Duration(seconds: 20));
      return res.statusCode >= 200 && res.statusCode < 300;
    }

    try {
      if (await tryPost()) return true;
    } catch (_) {}
    try {
      return await tryDelete();
    } catch (_) {
      return false;
    }
  }
}

class SlideshowPublishException implements Exception {
  SlideshowPublishException(this.statusCode, this.body);
  final int statusCode;
  final String body;
}
