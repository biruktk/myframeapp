import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';

class FaqService {
  final http.Client _http;
  FaqService({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  Future<List<FaqItem>> fetchFaqs() async {
    final base = ApiConfig.baseUrl.replaceAll(RegExp(r'/$'), '');
    final res = await _http.get(Uri.parse('$base/api/faqs'));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('FAQ fetch failed (${res.statusCode})');
    }
    final list = (jsonDecode(res.body) as List<dynamic>)
        .map((e) => FaqItem.fromJson(e as Map<String, dynamic>))
        .toList();
    return list;
  }
}

class FaqItem {
  FaqItem({
    required this.id,
    required this.question,
    required this.answer,
  });

  final String id;
  final String question;
  final String answer;

  factory FaqItem.fromJson(Map<String, dynamic> m) {
    return FaqItem(
      id: (m['id'] ?? '') as String,
      question: (m['question'] ?? '') as String,
      answer: (m['answer'] ?? '') as String,
    );
  }
}
