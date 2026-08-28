import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'device_store.dart';
import 'frame_api_client.dart';

/// Sleep Mode & Power Management store.
///
/// Persists the UI preference locally (SharedPreferences `sleep_settings_v1`)
/// and, whenever a frame is paired and the user saves, relays the strict
/// firmware protocol `wifi_sleep` payload to the frame over the server:
///  - `wifi_sleep`:  `{mode:1|0, begintime:"23:00", endtime:"07:00"}`
///
/// Album playback uses the `play` flow (`POST /api/frames/:mac/slideshow`),
/// not strategy_bin.
///
/// When a frame is paired/connected and the user has never saved a preference,
/// the toggle defaults **ON** with 23:00–07:00.
class SleepModeStore {
  SleepModeStore._();
  static final SleepModeStore instance = SleepModeStore._();

  static const _kKey = 'sleep_settings_v1';
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
  /// UI-only — does not push MQTT until the user actually saves.
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

  /// User changed toggle — mark as explicit preference.
  /// Persists locally only; call [pushConfigToFrame] to relay to the frame.
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
      }),
    );
  }

  /// `wifi_sleep` payload `data` per strict firmware protocol Section 5.3.
  ///
  /// Time contract: the server is authoritative for timezone math, but we also
  /// pre-compute the UTC wall-clock times client-side and flag `is_utc: true`
  /// so the backend can use the verified UTC values directly (defense against
  /// any server-side offset drift). The frame ALWAYS receives UTC `beginTime` /
  /// `endTime`, never local wall-clock times.
  Map<String, dynamic> buildWifiSleepData() {
    final offsetMinutes = DateTime.now().timeZoneOffset.inMinutes;
    if (!enabled) {
      return {
        'mode': 0,
        'begintime': '00:00',
        'endtime': '00:00',
        'timezoneOffsetMinutes': offsetMinutes,
        'is_utc': true,
        'utc_begintime': '00:00',
        'utc_endtime': '00:00',
      };
    }
    return {
      'mode': 2,
      'begintime': _toHhMm(startTime),
      'endtime': _toHhMm(endTime),
      'timezoneOffsetMinutes': offsetMinutes,
      'is_utc': true,
      'utc_begintime': _localToUtcHhMm(startTime, offsetMinutes),
      'utc_endtime': _localToUtcHhMm(endTime, offsetMinutes),
    };
  }

  /// Convert a LOCAL [TimeOfDay] wall-clock time to UTC HH:mm given the
  /// device's UTC offset in minutes (east of UTC). Wraps midnight correctly.
  static String _localToUtcHhMm(TimeOfDay local, int offsetMinutes) {
    final totalMinutes = ((local.hour * 60 + local.minute) - offsetMinutes) % 1440;
    final normalized = (totalMinutes + 1440) % 1440;
    final hh = (normalized ~/ 60).toString().padLeft(2, '0');
    final mm = (normalized % 60).toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  /// Relay `wifi_sleep` to the paired frame via the server.
  /// Best-effort: returns false if no frame is paired or the relay is unreachable.
  Future<bool> pushConfigToFrame() async {
    await ensureLoaded();
    await DeviceStore.instance.load();
    final mac = _frameMac();
    if (mac == null || mac.isEmpty) return false;
    final api = FrameApiClient();
    try {
      final result = await api.sendFrameCommand(
        mac: mac,
        action: 'wifi_sleep',
        data: buildWifiSleepData(),
      );
      return result['ok'] == true;
    } catch (_) {
      return false;
    } finally {
      api.close();
    }
  }

  /// First paired frame's MQTT (station/BLE) MAC, or null when unpaired.
  String? _frameMac() {
    for (final f in DeviceStore.instance.pairedFrames) {
      final mac = DeviceStore.macForPairedFrame(f);
      if (mac != null && mac.trim().isNotEmpty) return mac;
    }
    return null;
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
