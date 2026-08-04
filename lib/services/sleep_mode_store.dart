import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'device_store.dart';

/// Local sleep-mode UI mock (same behavior as WeChat mini-app `pages/sleep/sleep.js`).
///
/// Firmware sleep is not wired yet — this store is UI-only persistence.
/// When a frame is paired/connected and the user has never saved a preference,
/// the toggle defaults **ON** with 23:00–07:00.
class SleepModeStore {
  SleepModeStore._();
  static final SleepModeStore instance = SleepModeStore._();

  static const _kKey = 'mock_sleep_settings_v1';
  static const defaultStart = TimeOfDay(hour: 23, minute: 0);
  static const defaultEnd = TimeOfDay(hour: 7, minute: 0);

  bool enabled = false;
  TimeOfDay startTime = defaultStart;
  TimeOfDay endTime = defaultEnd;
  bool userPreferenceSet = false;
  var _loaded = false;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    await reload();
  }

  Future<void> reload() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kKey);
    if (raw == null || raw.isEmpty) {
      enabled = false;
      startTime = defaultStart;
      endTime = defaultEnd;
      userPreferenceSet = false;
    } else {
      try {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        enabled = m['enabled'] == true;
        startTime = _parseHhMm('${m['startTime'] ?? ''}', fallback: defaultStart);
        endTime = _parseHhMm('${m['endTime'] ?? ''}', fallback: defaultEnd);
        userPreferenceSet = m['userPreferenceSet'] == true;
      } catch (_) {
        enabled = false;
        startTime = defaultStart;
        endTime = defaultEnd;
        userPreferenceSet = false;
      }
    }
    _loaded = true;
  }

  /// Same rule as mini-app `resolveMockSettingsForUi`:
  /// connected frame + no explicit user choice → ON with default window.
  Future<void> resolveForUi() async {
    await ensureLoaded();
    await DeviceStore.instance.load();
    final connected = _isFrameConnected();
    if (connected && !userPreferenceSet) {
      enabled = true;
      // Defaults already applied in reload(); keep any previously stored times.
      await _persist(userPreferenceSet: false);
    }
  }

  /// User changed toggle or schedule — mark as explicit preference.
  Future<void> setEnabled(bool value) async {
    await ensureLoaded();
    enabled = value;
    userPreferenceSet = true;
    await _persist(userPreferenceSet: true);
  }

  Future<void> setSchedule({
    TimeOfDay? start,
    TimeOfDay? end,
  }) async {
    await ensureLoaded();
    if (start != null) startTime = start;
    if (end != null) endTime = end;
    userPreferenceSet = true;
    await _persist(userPreferenceSet: true);
  }

  Future<void> _persist({required bool userPreferenceSet}) async {
    this.userPreferenceSet = userPreferenceSet;
    final p = await SharedPreferences.getInstance();
    await p.setString(
      _kKey,
      jsonEncode({
        'enabled': enabled,
        'startTime': _toHhMm(startTime),
        'endTime': _toHhMm(endTime),
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
        'userPreferenceSet': userPreferenceSet,
        'mockOnly': true,
      }),
    );
  }

  /// Mini-app: paired / home-connected frame. Flutter: any stored paired frame.
  bool _isFrameConnected() {
    final frames = DeviceStore.instance.pairedFrames;
    return frames.any((f) => f.deviceId.trim().isNotEmpty);
  }

  static String _toHhMm(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  static TimeOfDay _parseHhMm(String raw, {required TimeOfDay fallback}) {
    final parts = raw.trim().split(':');
    if (parts.length < 2) return fallback;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
      return fallback;
    }
    return TimeOfDay(hour: h, minute: m);
  }
}
