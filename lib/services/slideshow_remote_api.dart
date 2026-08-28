import 'dart:convert';

import 'protocol_logger_service.dart';

import '../config/api_config.dart';
import 'api_client.dart';

class SlideshowRemoteApi {
  SlideshowRemoteApi({String? baseUrl})
      : _origin = (baseUrl ?? ApiConfig.baseUrl).replaceAll(RegExp(r'/+$'), '');

  final String _origin;

  /// Publish a playlist/slideshow to the frame. Returns the backend dispatch
  /// taskId (for hardware-ACK background tracking) or null when unavailable.
  Future<String?> publish({
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
    /// Isolation tag forwarded to the backend ('direct_cast' | 'playlist').
    String source = 'direct_cast',
  }) async {
    if (imageIds.isEmpty) return null;    final encoded = Uri.encodeComponent(macSlug);
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
    final intervalSec = finalIntervalMinutes * 60;

    // Strict firmware protocol (v1.3 §2.10):
    //  - begintime/endtime are a DAILY playback window "00:00"–"23:59"
    //    (never 00:00–00:00 which the firmware treats as zero-length).
    //  - the triple interval fields keep the device's NVS refresh timer in sync.
    //  - skipPlay is sent explicitly (false = push photo[0] now).
    final body = <String, dynamic>{
      'imageIds': imageIds,
      'intervalMinutes': finalIntervalMinutes,
      'interval_sec': intervalSec,
      'global_interval': intervalSec,
      'intervalUnit': finalIntervalUnit,
      'strategy': strategy,
      'begintime': '00:00',
      'endtime': '23:59',
      'idle': 1,
      'skipPlay': skipPlay,
      // Immediate first-photo push: the backend fires an MQTT `play` command
      // for `imageIds[0]` immediately after `strategy_bin`. Default ON so the
      // device displays the first new photo right away.
      'immediatePlay': immediatePlay,
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
    // Return the backend dispatch-queue taskId so callers can poll hardware
    // ACK status (background push indicator + completion notification).
    try {
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      final taskId = decoded['task_id'];
      if (taskId is String && taskId.isNotEmpty) return taskId;
    } catch (_) {}
    return null;
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
