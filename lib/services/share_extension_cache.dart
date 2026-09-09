import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../settings/app_settings.dart';
import 'app_diag_log.dart';
import 'device_store.dart';
import 'external_share_inbox.dart';

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

  static const MethodChannel _channel = MethodChannel(
    'myframe/share_extension/cache',
  );

  /// Frame list mirrored to the extension (JSON array of frame rows).
  static const String framesKey = 'ShareExtensionFrames';

  /// User's last frame selection (JSON array of device ids).
  static const String selectedFramesKey = 'ShareExtensionSelectedFrameIds';

  /// Bearer JWT + user id the extension sends as `Authorization`.
  static const String authTokenKey = 'ShareExtensionAuthToken';
  static const String authUserIdKey = 'ShareExtensionAuthUserId';

  /// Global playback profile keys mirrored to the App Group so the Share
  /// Extension builds external-share payloads with the user's saved interval
  /// instead of the hardcoded 10-minute default.
  static const String globalDisplaySecondsKey = 'global_display_seconds';
  static const String globalPlaybackModeKey = 'global_playback_mode';
  static const String globalDurationTypeKey = 'global_duration_type';

  /// Pending external shares written by the native Share Extension (JSON list of
  /// `{filePaths, isPlaylist, timestamp, pushes:[{mac,msgid}]}`). The extension
  /// cannot run Flutter, so the MAIN app ingests them (persist to Personal /
  /// Playlists + attach UploadQueueController tracking) on launch/resume.
  static const String pendingExternalSharesKey = 'pending_external_shares';
  static const String autoSendKey = 'ShareExtensionAutoSend';

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

    await Future.wait([syncFrames(), _syncAuthFrom(settings)]);
  }

  void _onDeviceRevision() {
    unawaited(syncFrames());
  }

  void _onSettingsChanged() {
    final settings = _settings;
    if (settings == null) return;
    unawaited(_syncAuthFrom(settings));
  }

  static final Set<String> onlineDeviceIds = {};

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
        final targetId = uploadTargets.isNotEmpty
            ? uploadTargets.first
            : f.deviceId;
        final isOnline = onlineDeviceIds.contains(f.deviceId);
        return {
          'id': f.deviceId,
          'name': name,
          'mac': targetId,
          'apiUrl': f.resolvedApiBaseUrl,
          'pairingToken': f.resolvedPairingToken,
          'is_online': isOnline,
        };
      }).toList();
      await _channel.invokeMethod<void>('write', {
        'key': framesKey,
        'value': jsonEncode(rows),
      });
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
      await _channel.invokeMethod<void>('write', {
        'key': authTokenKey,
        'value': token,
      });
      await _channel.invokeMethod<void>('write', {
        'key': authUserIdKey,
        'value': userId,
      });
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
      AppDiagLog.verbose(
        '[ShareExtensionCache] readSelectedFrameIds failed: $e',
      );
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
      AppDiagLog.verbose(
        '[ShareExtensionCache] writeSelectedFrameIds failed: $e',
      );
    }
  }

  /// Mirrors the user's global playback rules into the App Group defaults so
  /// the native Share Extension uploads with the saved interval/order/duration
  /// rather than the hardcoded 600 s / sequential fallback.
  Future<void> syncPlaybackRules({
    required int displaySeconds,
    required String playbackMode,
    required String durationType,
  }) async {
    if (!_isApple) return;
    try {
      await _channel.invokeMethod<void>('write', {
        'key': globalDisplaySecondsKey,
        'value': displaySeconds,
      });
      await _channel.invokeMethod<void>('write', {
        'key': globalPlaybackModeKey,
        'value': playbackMode,
      });
      await _channel.invokeMethod<void>('write', {
        'key': globalDurationTypeKey,
        'value': durationType,
      });
    } catch (e) {
      AppDiagLog.verbose('[ShareExtensionCache] syncPlaybackRules failed: $e');
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
      final flagged = await _channel.invokeMethod<bool?>('readBool', {
        'key': autoSendKey,
      });
      if (flagged != true) return const [];
      final ids = await readSelectedFrameIds();
      await _channel.invokeMethod<void>('remove', {'key': autoSendKey});
      return ids;
    } catch (e) {
      AppDiagLog.verbose('[ShareExtensionCache] consumeAutoSend failed: $e');
      return const [];
    }
  }

  Future<void> acknowledgePendingShare(
    String id, {
    List<String> paths = const [],
  }) async {
    await _channel.invokeMethod<void>('acknowledgeShare', {
      'key': pendingExternalSharesKey,
      'id': id,
      'paths': paths,
    });
  }

  /// Reads pending native sessions without deleting them. The host first saves
  /// the local gallery record, then acknowledges a completed session by ID.
  /// Native uploads stay owned by the extension; these records never redispatch.
  Future<List<PendingExternalShare>> consumePendingExternalShares() async {
    if (!_isApple) return const [];
    try {
      final raw = await _channel.invokeMethod<String?>('readString', {
        'key': pendingExternalSharesKey,
      });
      if (raw == null || raw.trim().isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final out = <PendingExternalShare>[];
      for (final e in decoded) {
        if (e is! Map) continue;
        final paths =
            (e['filePaths'] as List?)
                ?.whereType<String>()
                .map((p) => p.trim())
                .where((p) => p.isNotEmpty)
                .toList() ??
            const <String>[];
        if (paths.isEmpty) continue;
        final pushes = <PendingExternalPush>[];
        final rawPushes = e['pushes'];
        if (rawPushes is List) {
          for (final p in rawPushes) {
            if (p is! Map) continue;
            final mac = '${p['mac'] ?? ''}'.trim();
            final msgid = '${p['msgid'] ?? ''}'.trim();
            if (mac.isNotEmpty && msgid.isNotEmpty) {
              pushes.add(PendingExternalPush(mac: mac, msgid: msgid));
            }
          }
        }
        out.add(
          PendingExternalShare(
            id: '${e['id'] ?? ExternalShareInbox.keyFor(paths)}',
            completed: e['state'] == null || e['state'] == 'completed',
            failed: e['state'] == 'failed',
            progress: (e['progress'] as num?)?.toDouble() ?? 0,
            paths: paths,
            isPlaylist: e['isPlaylist'] == true || paths.length > 1,
            pushes: pushes,
          ),
        );
      }
      return out;
    } catch (e) {
      AppDiagLog.verbose(
        '[ShareExtensionCache] consumePendingExternalShares failed: $e',
      );
      return const [];
    }
  }
}

/// A share recorded by the native iOS Share Extension for deferred ingestion by
/// the host Flutter app. Files live in the shared App Group container.
class PendingExternalShare {
  const PendingExternalShare({
    required this.paths,
    required this.id,
    this.completed = true,
    this.failed = false,
    this.progress = 0,
    required this.isPlaylist,
    this.pushes = const [],
  });

  /// Transcoded JPEG paths inside the shared App Group container.
  final List<String> paths;
  final String id;
  final bool completed;
  final bool failed;
  final double progress;

  /// true = 2+ images (Playlists tab), false = single image (Personal tab).
  final bool isPlaylist;

  /// Tracked backend push jobs (per target frame) that the extension fired —
  /// used to attach [UploadQueueController.trackPush] so the progress banner
  /// shows the render progress when the host app next opens.
  final List<PendingExternalPush> pushes;
}

/// A backend push job (mac + msgid) already dispatched by the Share Extension.
class PendingExternalPush {
  const PendingExternalPush({required this.mac, required this.msgid});

  /// Upload target MAC (12-hex station MAC) the push job was created for.
  final String mac;

  /// Push-queue job msgid returned by the backend at dispatch time.
  final String msgid;
}
