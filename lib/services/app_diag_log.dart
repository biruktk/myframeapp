import 'package:flutter/foundation.dart';

/// Developer vs production logging. Verbose output is shown only when the user
/// enables Debug mode in Settings → Application → Debug mode.
class AppDiagLog {
  AppDiagLog._();

  static bool _debugEnabled = false;
  static final List<String> _buffer = [];
  static const int _maxLines = 500;
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static bool get isDebugEnabled => _debugEnabled;

  static List<String> get lines => List.unmodifiable(_buffer);

  static void setDebugEnabled(bool value) {
    _debugEnabled = value;
    if (!value) {
      clear();
    }
  }

  static void clear() {
    if (_buffer.isEmpty) return;
    _buffer.clear();
    revision.value++;
  }

  static String _stamp() {
    final t = DateTime.now().toIso8601String();
    return t.length >= 19 ? t.substring(11, 19) : t;
  }

  /// Append a line to the on-screen slog buffer (debug mode only).
  static void log(String message) {
    if (!_debugEnabled) return;
    final line = '${_stamp()} $message';
    _buffer.add(line);
    if (_buffer.length > _maxLines) {
      _buffer.removeRange(0, _buffer.length - _maxLines);
    }
    revision.value++;
    debugPrint(line);
  }

  /// Technical log line (console + slog buffer). Suppressed unless debug mode is on.
  static void verbose(String message) => log(message);

  /// Status text for on-screen labels. Verbose when debug is on; short English otherwise.
  static String userFacingStatus(
    String raw, {
    String fallback = 'Something went wrong. Please try again.',
  }) {
    if (_debugEnabled) return raw;
    return publicStatusLine(raw) ?? fallback;
  }

  /// One-line production-safe status (e.g. MQTT connected). No IDs or tokens.
  static String? publicStatusLine(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('mqtt') &&
        (lower.contains('connected') ||
            lower.contains('online') ||
            lower.contains('session'))) {
      return 'MQTT connected';
    }
    if (lower.contains('waking') || lower.contains('connecting to your frame')) {
      return 'Connecting to frame…';
    }
    if (lower.contains('preparing photo') || lower.contains('preparing')) {
      return 'Preparing photo…';
    }
    if (lower.contains('upload') ||
        lower.contains('sending') ||
        lower.contains('delivering')) {
      return 'Sending to frame…';
    }
    if (lower.contains('delivered') ||
        lower.contains('displayed') ||
        lower.contains('success') ||
        lower.contains('sent to frame')) {
      return 'Photo sent to frame';
    }
    if (lower.contains('fail') ||
        lower.contains('error') ||
        lower.contains('offline') ||
        lower.contains('could not') ||
        lower.contains('missing')) {
      return _trimForUser(raw);
    }
    return null;
  }

  static String _trimForUser(String raw) {
    final t = raw.trim();
    if (t.length <= 120) return t;
    return '${t.substring(0, 117)}…';
  }

  /// Cast log line for the editor UI.
  static String? castUiLine(String phaseName, String message) {
    if (_debugEnabled) {
      return '${_stamp()} [$phaseName] $message';
    }
    return publicStatusLine(message);
  }
}
