import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';

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
  }) async {
    if (imageIds.isEmpty) return;
    final encoded = Uri.encodeComponent(macSlug);
    final uri = Uri.parse('$_origin/api/frames/$encoded/slideshow');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final bt = bearerToken?.trim() ?? '';
    if (bt.isNotEmpty) {
      headers['Authorization'] = 'Bearer $bt';
    }
    final pt = pairingToken?.trim() ?? '';
    if (pt.isNotEmpty) {
      headers['x-pairing-token'] = pt;
    }
    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    final body = <String, dynamic>{
      'imageIds': imageIds,
      'intervalMinutes': intervalMinutes,
      'strategy': strategy,
      'begintime': nowMs.toString(),
      'endtime': durationHours > 0 ? (nowMs + durationHours * 3600 * 1000).toString() : '',
      'idle': 0,
    };
    if (skipPlay) body['skipPlay'] = true;
    final res = await http.post(
      uri,
      headers: headers,
      body: jsonEncode(body),
    );
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
    final slug = macSlug.trim();
    if (slug.isEmpty) return false;
    final encoded = Uri.encodeComponent(slug);
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final bt = bearerToken?.trim() ?? '';
    if (bt.isNotEmpty) {
      headers['Authorization'] = 'Bearer $bt';
    }
    final pt = pairingToken?.trim() ?? '';
    if (pt.isNotEmpty) {
      headers['x-pairing-token'] = pt;
    }

    Future<bool> tryPost() async {
      final uri = Uri.parse('$_origin/api/frames/$encoded/stop-playlist');
      final res = await http
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
      final res = await http
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
