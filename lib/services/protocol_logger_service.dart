import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class ProtocolLogEntry {
  final DateTime timestamp;
  final String category;
  final String message;

  ProtocolLogEntry({
    required this.timestamp,
    required this.category,
    required this.message,
  });

  String get formattedTime {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    final s = timestamp.second.toString().padLeft(2, '0');
    final ms = timestamp.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }

  @override
  String toString() {
    return '[$formattedTime] [$category] $message';
  }
}

class ProtocolLoggerService {
  ProtocolLoggerService._();
  static final ProtocolLoggerService instance = ProtocolLoggerService._();

  static const int _maxLogs = 500;
  final List<ProtocolLogEntry> _logs = [];

  final ValueNotifier<int> logCountNotifier = ValueNotifier<int>(0);

  List<ProtocolLogEntry> get logs => UnmodifiableListView(_logs);

  String get logsFormatted {
    return _logs.map((e) => e.toString()).join('\n');
  }

  void log(String category, String message) {
    final entry = ProtocolLogEntry(
      timestamp: DateTime.now(),
      category: category,
      message: message,
    );
    _logs.add(entry);
    if (_logs.length > _maxLogs) {
      _logs.removeAt(0);
    }
    logCountNotifier.value = _logs.length;
  }

  void logMqttOut(String action, Map<String, dynamic> payload) {
    log('MQTT OUT', 'action: $action | $payload');
  }

  void logMqttIn(String topic, String payload) {
    log('MQTT IN', 'topic: $topic | $payload');
  }

  void logApi(String method, String path, {dynamic body, int? statusCode}) {
    final statusStr = statusCode != null ? ' (HTTP $statusCode)' : '';
    final bodyStr = body != null ? ' | body: $body' : '';
    log('API $method', '$path$statusStr$bodyStr');
  }

  void clear() {
    _logs.clear();
    logCountNotifier.value = 0;
  }

  Future<bool> copyToClipboard() async {
    final text = logsFormatted;
    if (text.isEmpty) return false;
    await Clipboard.setData(ClipboardData(text: text));
    return true;
  }
}
