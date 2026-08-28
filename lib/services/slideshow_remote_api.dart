import 'dart:convert';

import 'protocol_logger_service.dart';

import '../config/api_config.dart';
import 'api_client.dart';

class SlideshowRemoteApi {
  SlideshowRemoteApi({String? baseUrl})
      : _origin = (baseUrl ?? ApiConfig.baseUrl).replaceAll(RegExp(r'/+$'), '');

  final String _origin;

  /// Publish a playlist/slideshow to the frame.
  ///
  /// Sends the strict 1037346b firmware-protocol payload that the backend
  /// pubnspwards 1:1 to the device as a `strategy_bin` MQTT command:
  ///   { imageIds, intervalMinutes, strategy, idle, begintime:"00:00",
  ///     endtime:"23:59", skipPlay }
  ///
  /// The device autonomously fetches the manifest + .bin files and rotates
  /// per the configured interval. The dispatch is fire-and-forget — a 2xx
  /// response is treated as immediate success (no task-id polling).
  Future<void> publish({
    String? bearerToken,
    String? pairingToken,
    required String macSlug,
    required List<String> imageIds,
    required int intervalMinutes,
    int strategy = 1,
    int durationHours = 0,
    bool skipPlay = false,
    /// Routing hint only (newer clients). Defaults to `'minute'`. Backend
    /// reads both `intervalMinutes` and `intervalUnit`.
    String intervalUnit = 'minute',
    /// Explicit seconds override. When set (>0), takes precedence over
    /// `intervalMinutes` and forces intervalUnit='second'.
    int? intervalSeconds,
    /// Isolation tag forwarded to the backend
    /// (`'direct_cast'` | `'playlist'`).
    String source = 'direct_cast',
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

    // Interval unit normalisation: prefer `intervalSeconds` (seconds) when
    // provided; otherwise fall back to `intervalMinutes` with explicit unit.
    int finalIntervalMinutes = intervalMinutes;
    String finalIntervalUnit = intervalUnit;
    if (intervalSeconds != null && intervalSeconds > 0) {
      finalIntervalMinutes = (intervalSeconds / 60).ceil();
      finalIntervalUnit = 'second';
    }
    if (finalIntervalMinutes < 1) finalIntervalMinutes = 1;

    // Strict firmware protocol — daily playback window + explicit strategy.
    final body = <String, dynamic>{
      'imageIds': imageIds,
      'intervalMinutes': finalIntervalMinutes,
      'intervalUnit': finalIntervalUnit,
      'strategy': strategy,
      'begintime': '00:00',
      'endtime': '23:59',
      'idle': 1,
      'skipPlay': skipPlay,
      'source': source,
    };
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
