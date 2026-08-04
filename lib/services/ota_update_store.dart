import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'device_store.dart';

/// OTA auto-update preference — same UX rule as [SleepModeStore]:
/// when a frame is paired/connected and the user has never saved a preference,
/// the toggle defaults **ON**. Explicit OFF (or ON) is remembered.
class OtaUpdateStore {
  OtaUpdateStore._();
  static final OtaUpdateStore instance = OtaUpdateStore._();

  static const _kKey = 'mock_ota_auto_update_v1';

  bool enabled = false;
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
      userPreferenceSet = false;
    } else {
      try {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        enabled = m['enabled'] == true;
        userPreferenceSet = m['userPreferenceSet'] == true;
      } catch (_) {
        enabled = false;
        userPreferenceSet = false;
      }
    }
    _loaded = true;
  }

  /// Connected frame + no explicit user choice → ON.
  Future<void> resolveForUi() async {
    await ensureLoaded();
    await DeviceStore.instance.load();
    final connected = _isFrameConnected();
    if (connected && !userPreferenceSet) {
      enabled = true;
      await _persist(userPreferenceSet: false);
    }
  }

  /// User flipped the switch — remember the choice.
  Future<void> setEnabled(bool value) async {
    await ensureLoaded();
    enabled = value;
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
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
        'userPreferenceSet': userPreferenceSet,
      }),
    );
  }

  bool _isFrameConnected() {
    final frames = DeviceStore.instance.pairedFrames;
    return frames.any((f) => f.deviceId.trim().isNotEmpty);
  }
}
