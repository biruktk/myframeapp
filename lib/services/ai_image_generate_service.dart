import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Generates frame-ready images via OpenAI DALL·E 3 or Google Imagen (Gemini API key).
class AiImageGenerateService {
  AiImageGenerateService._();
  static final AiImageGenerateService instance = AiImageGenerateService._();

  static const _openAiUrl = 'https://api.openai.com/v1/images/generations';
  static const _geminiImagenUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/imagen-3.0-generate-002:predict';

  Future<Uint8List> generate({
    required String provider,
    required String apiKey,
    required String prompt,
  }) async {
    final key = apiKey.trim();
    if (key.isEmpty) {
      throw AiImageGenerateException('missing_api_key');
    }
    final p = prompt.trim();
    if (p.isEmpty) {
      throw AiImageGenerateException('empty_prompt');
    }

    if (provider == 'gemini') {
      return _generateGemini(key, p);
    }
    return _generateOpenAi(key, p);
  }

  Future<Uint8List> _generateOpenAi(String apiKey, String prompt) async {
    final res = await http
        .post(
          Uri.parse(_openAiUrl),
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': 'dall-e-3',
            'prompt': prompt,
            'n': 1,
            'size': '1024x1024',
            'response_format': 'b64_json',
          }),
        )
        .timeout(const Duration(seconds: 120));

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw AiImageGenerateException(_extractError(res.body) ?? 'openai_http_${res.statusCode}');
    }

    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final data = json['data'];
    if (data is! List || data.isEmpty) {
      throw AiImageGenerateException('openai_empty_response');
    }
    final first = data.first;
    if (first is! Map<String, dynamic>) {
      throw AiImageGenerateException('openai_bad_payload');
    }
    final b64 = first['b64_json'] as String?;
    if (b64 == null || b64.isEmpty) {
      throw AiImageGenerateException('openai_no_image');
    }
    return Uint8List.fromList(base64Decode(b64));
  }

  Future<Uint8List> _generateGemini(String apiKey, String prompt) async {
    final uri = Uri.parse('$_geminiImagenUrl?key=${Uri.encodeComponent(apiKey)}');
    final res = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'instances': [
              {'prompt': prompt},
            ],
            'parameters': {
              'sampleCount': 1,
              'aspectRatio': '3:4',
            },
          }),
        )
        .timeout(const Duration(seconds: 120));

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw AiImageGenerateException(_extractError(res.body) ?? 'gemini_http_${res.statusCode}');
    }

    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final predictions = json['predictions'];
    if (predictions is! List || predictions.isEmpty) {
      throw AiImageGenerateException('gemini_empty_response');
    }
    final first = predictions.first;
    if (first is! Map<String, dynamic>) {
      throw AiImageGenerateException('gemini_bad_payload');
    }
    final b64 = first['bytesBase64Encoded'] as String?;
    if (b64 == null || b64.isEmpty) {
      throw AiImageGenerateException('gemini_no_image');
    }
    return Uint8List.fromList(base64Decode(b64));
  }

  static String? _extractError(String body) {
    try {
      final j = jsonDecode(body);
      if (j is Map<String, dynamic>) {
        final err = j['error'];
        if (err is Map<String, dynamic>) {
          final msg = err['message'] as String?;
          if (msg != null && msg.trim().isNotEmpty) return msg.trim();
        }
        final msg = j['message'] as String?;
        if (msg != null && msg.trim().isNotEmpty) return msg.trim();
      }
    } catch (_) {}
    return null;
  }
}

class AiImageGenerateException implements Exception {
  AiImageGenerateException(this.code, [this.detail]);

  final String code;
  final String? detail;

  @override
  String toString() => detail == null ? code : '$code: $detail';
}
