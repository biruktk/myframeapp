import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Normalizes SSIDs from Android [WifiInfo] / scan (often wrapped in `"`…`"`).
String normalizeWifiSsid(String? raw) {
  if (raw == null) return '';
  var s = raw.trim();
  final lower = s.toLowerCase();
  if (lower == '<unknown ssid>' || lower == 'unknown ssid') {
    return '';
  }
  while (s.length >= 2 && s.startsWith('"') && s.endsWith('"')) {
    s = s.substring(1, s.length - 1).trim();
  }
  return s;
}

bool wifiSsidEquals(String? a, String? b) => normalizeWifiSsid(a) == normalizeWifiSsid(b);

/// Remembers Wi‑Fi passwords this app has used successfully (not the OS keychain).
///
/// Android does not expose saved system Wi‑Fi passwords to third‑party apps; we
/// persist credentials after successful frame provisioning so reconnecting is one tap.
class WifiCredentialCache {
  WifiCredentialCache._();
  static final WifiCredentialCache instance = WifiCredentialCache._();

  static const _k = 'myframe_wifi_cred_map_v1';
  static const _maxEntries = 28;

  Future<Map<String, String>> _readMap() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_k);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      final out = <String, String>{};
      for (final e in decoded.entries) {
        final k = normalizeWifiSsid(e.key.toString());
        if (k.isEmpty) continue;
        out[k] = e.value.toString();
      }
      return out;
    } catch (_) {
      return {};
    }
  }

  Future<String?> passwordFor(String ssid) async {
    final key = normalizeWifiSsid(ssid);
    if (key.isEmpty) return null;
    final m = await _readMap();
    return m[key];
  }

  Future<void> remember(String ssid, String password) async {
    final key = normalizeWifiSsid(ssid);
    if (key.isEmpty || password.isEmpty) return;
    final m = await _readMap();
    m[key] = password;
    while (m.length > _maxEntries) {
      m.remove(m.keys.first);
    }
    final p = await SharedPreferences.getInstance();
    await p.setString(_k, jsonEncode(m));
  }
}
