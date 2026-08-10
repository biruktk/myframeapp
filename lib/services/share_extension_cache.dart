import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../settings/app_settings.dart';
import 'app_diag_log.dart';
import 'device_store.dart';

/// Keys shared with the native iOS Share Extension (App Group defaults).
///
/// The extension cannot run Flutter, so the host mirrors the data the native
/// bottom sheet + background uploader needs into the App Group:
///  - the paired-frame list (with resolved upload target / base URL / pairing
///    token) so the extension can upload directly,
///  - the user's JWT so the extension can authenticate the upload,
///  - the user's last frame selection so the sheet pre-selects it.
class ShareExtensionCache {
  ShareExtensionCache._();

  static final ShareExtensionCache instance = ShareExtensionCache._();

  static const MethodChannel _channel =
      MethodChannel('myframe/share_extension/cache');

  /// Frame list mirrored to the extension (JSON array of frame rows).
  static const String framesKey = 'ShareExtensionFrames';

  /// User's last frame selection (JSON array of device ids).
  static const String selectedFramesKey = 'ShareExtensionSelectedFrameIds';

  /// Bearer JWT + user id the extension sends as `Authorization`.
  static const String authTokenKey = 'ShareExtensionAuthToken';
  static const String authUserIdKey = 'ShareExtensionAuthUserId';

  bool _bootstrapped = false;
  bool _isApple = false;
  AppSettings? _settings;

  String _lastToken = '';
  String _lastUserId = '';

  bool get isSupported => _isApple;

  /// Call once at startup (iOS only) with the loaded [settings]. Mirrors the
  /// paired frames + auth so the native share sheet can show cached targets and
  /// upload straight from the extension.
  Future<void> bootstrap({required AppSettings settings}) async {
    if (_bootstrapped) return;
    _bootstrapped = true;
    _isApple = !kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS);
    _settings = settings;

    if (!_isApple) return;

    // Re-mirror auth whenever the session changes (login / refresh / sign-out).
    settings.addListener(_onSettingsChanged);

    // Re-mirror frames whenever pairing changes.
    DeviceStore.instance.revision.addListener(_onDeviceRevision);

    await Future.wait([
      syncFrames(),
      _syncAuthFrom(settings),
    ]);
  }

  void _onDeviceRevision() {
    unawaited(syncFrames());
  }

  void _onSettingsChanged() {
    final settings = _settings;
    if (settings == null) return;
    unawaited(_syncAuthFrom(settings));
  }

  /// Writes the current paired-frame list (incl. upload target / base URL /
  /// pairing token) into the App Group defaults.
  Future<void> syncFrames() async {
    if (!_isApple) return;
    try {
      await DeviceStore.instance.load();
      final rows = DeviceStore.instance.pairedFrames.map((f) {
        final name = f.frameName?.trim().isNotEmpty == true
            ? f.frameName!.trim()
            : f.deviceId;
        // The same identity `FrameApiClient.uploadPhoto` uses for the URL slug
        // and `device_id` field (station MAC preferred over BLE id).
        final uploadTargets = f.resolvedFrameUploadTargets;
        final targetId =
            uploadTargets.isNotEmpty ? uploadTargets.first : f.deviceId;
        return {
          'id': f.deviceId,
          'name': name,
          'mac': targetId,
          'apiUrl': f.resolvedApiBaseUrl,
          'pairingToken': f.resolvedPairingToken,
        };
      }).toList();
      await _channel.invokeMethod<void>(
        'write',
        {'key': framesKey, 'value': jsonEncode(rows)},
      );
    } catch (e) {
      AppDiagLog.verbose('[ShareExtensionCache] syncFrames failed: $e');
    }
  }

  Future<void> _syncAuthFrom(AppSettings settings) async {
    if (!_isApple) return;
    final token = settings.authToken.trim();
    final userId = settings.authUserId.trim();
    if (token == _lastToken && userId == _lastUserId) return;
    _lastToken = token;
    _lastUserId = userId;
    try {
      await _channel.invokeMethod<void>(
        'write',
        {'key': authTokenKey, 'value': token},
      );
      await _channel.invokeMethod<void>(
        'write',
        {'key': authUserIdKey, 'value': userId},
      );
    } catch (e) {
      AppDiagLog.verbose('[ShareExtensionCache] syncAuth failed: $e');
    }
  }

  /// Reads the frame ids the user selected in the native sheet (cached).
  Future<List<String>> readSelectedFrameIds() async {
    if (!_isApple) return const [];
    try {
      final value = await _channel.invokeMethod<String>('readString', {
        'key': selectedFramesKey,
      });
      if (value == null || value.isEmpty) return const [];
      final decoded = jsonDecode(value);
      if (decoded is List) {
        return decoded.whereType<String>().toList();
      }
    } catch (e) {
      AppDiagLog.verbose('[ShareExtensionCache] readSelectedFrameIds failed: $e');
    }
    return const [];
  }

  /// Persists the frames actually used so the next share pre-selects them.
  Future<void> writeSelectedFrameIds(Iterable<String> ids) async {
    if (!_isApple) return;
    try {
      await _channel.invokeMethod<void>('write', {
        'key': selectedFramesKey,
        'value': jsonEncode(ids.toList(growable: false)),
      });
    } catch (e) {
      AppDiagLog.verbose('[ShareExtensionCache] writeSelectedFrameIds failed: $e');
    }
  }

  /// Consumes the extension's auto-send hand-off: returns the pre-selected
  /// frame ids and clears the flag + selection so the next share re-asks.
  ///
  /// Kept for backwards compatibility with builds that still redirect to the
  /// host app; the current extension uploads in-process and never sets the flag.
  Future<List<String>> consumeAutoSend() async {
    if (!_isApple) return const [];
    try {
      const autoSendKey = 'ShareExtensionAutoSend';
      final flagged = await _channel.invokeMethod<bool?>(
        'readBool',
        {'key': autoSendKey},
      );
      if (flagged != true) return const [];
      final ids = await readSelectedFrameIds();
      await _channel.invokeMethod<void>('remove', {'key': autoSendKey});
      return ids;
    } catch (e) {
      AppDiagLog.verbose('[ShareExtensionCache] consumeAutoSend failed: $e');
      return const [];
    }
  }
}
