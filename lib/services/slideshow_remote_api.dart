import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';

class SlideshowRemoteApi {
  SlideshowRemoteApi({String? baseUrl})
      : _origin = (baseUrl ?? ApiConfig.baseUrl).replaceAll(RegExp(r'/+$'), '');

  final String _origin;

  /// POST `/api/frames/:mac/slideshow` — [macSlug] hex without separators or encoded path segment.
  Future<void> publish({
    required String bearerToken,
    required String macSlug,
    required List<String> imageIds,
    required int intervalMinutes,
  }) async {
    final t = bearerToken.trim();
    if (t.isEmpty || imageIds.isEmpty) return;
    final encoded = Uri.encodeComponent(macSlug);
    final uri = Uri.parse('$_origin/api/frames/$encoded/slideshow');
    final res = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $t',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({'imageIds': imageIds, 'intervalMinutes': intervalMinutes}),
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
