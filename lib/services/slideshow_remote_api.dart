import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';

class SlideshowRemoteApi {
  SlideshowRemoteApi({String? baseUrl})
      : _origin = (baseUrl ?? ApiConfig.baseUrl).replaceAll(RegExp(r'/+$'), '');

  final String _origin;

  /// POST `/api/frames/:mac/slideshow` — [macSlug] hex without separators or encoded path segment.
  /// Sends Bearer token if available, else falls back to x-pairing-token.
  Future<void> publish({
    String? bearerToken,
    String? pairingToken,
    required String macSlug,
    required List<String> imageIds,
    required int intervalMinutes,
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
    final body = <String, dynamic>{
      'imageIds': imageIds,
      'intervalMinutes': intervalMinutes,
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
}

class SlideshowPublishException implements Exception {
  SlideshowPublishException(this.statusCode, this.body);
  final int statusCode;
  final String body;
}
