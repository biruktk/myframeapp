import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../models/frame_playback_profile.dart';
import 'app_diag_log.dart';
import 'api_client.dart';
import 'device_store.dart';
import 'frame_ble_mac_slug.dart';
import 'local_storage_service.dart';
import 'share_extension_cache.dart';
import 'slideshow_playlist_store.dart';
import 'slideshow_remote_api.dart';

/// Persists the global Frame Profile (playback defaults) per frame, locally
/// scoped to the active account, and pushes it to the frame's server profile.
class FrameSettingsStore {
  FrameSettingsStore._();
  static final FrameSettingsStore instance = FrameSettingsStore._();

  static const _base = 'frame_playback_profile';

  FramePlaybackProfile? _active;

  FramePlaybackProfile get current => _active ?? const FramePlaybackProfile();

  Future<String> _key(PairedFrame? paired) async {
    final mac = frameBleMacSlug(paired);
    return LocalStorageService.instance.scopedKey('${_base}_$mac');
  }

  /// Loads the profile for [paired]; returns the default profile when unset.
  Future<FramePlaybackProfile> load(PairedFrame? paired) async {
    try {
      final key = await _key(paired);
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw != null && raw.isNotEmpty) {
        _active = FramePlaybackProfile.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
        return _active!;
      }
    } catch (e, st) {
      AppDiagLog.verbose('[FrameSettingsStore] load failed: $e\n$st');
    }
    _active = const FramePlaybackProfile();
    return _active!;
  }

  /// Keys the native Share Extension / ShareActivity read for the user's
  /// global playback profile (kept in sync by [_syncGlobalPlaybackDefaults]).
  static const String globalDisplaySecondsKey = 'global_display_seconds';
  static const String globalPlaybackModeKey = 'global_playback_mode';
  static const String globalDurationTypeKey = 'global_duration_type';

  Future<void> save(PairedFrame? paired, FramePlaybackProfile profile) async {
    _active = profile;
    try {
      final key = await _key(paired);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, jsonEncode(profile.toJson()));
    } catch (e, st) {
      AppDiagLog.verbose('[FrameSettingsStore] save failed: $e\n$st');
    }
    await _syncGlobalPlaybackDefaults(profile);
  }

  /// Mirrors the user's global playback defaults into the platform stores the
  /// native share UIs read when building external-share payloads:
  ///  - Android: shared `SharedPreferences` (`flutter.global_*`), which
  ///    `ShareActivity` reads via `FlutterSharedPreferences`.
  ///  - iOS: the App Group container (`UserDefaults(suiteName: group.com.myframe)`),
  ///    which the Share Extension reads directly.
  Future<void> _syncGlobalPlaybackDefaults(FramePlaybackProfile profile) async {
    final displaySeconds = profile.intervalMinutes * 60;
    final durationType = profile.durationHours == 0
        ? 'unlimited'
        : '${profile.durationHours}h';
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(globalDisplaySecondsKey, displaySeconds);
      await prefs.setString(globalPlaybackModeKey, profile.playbackMode);
      await prefs.setString(globalDurationTypeKey, durationType);
    } catch (e, st) {
      AppDiagLog.verbose(
        '[FrameSettingsStore] global defaults sync failed: $e\n$st',
      );
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      await ShareExtensionCache.instance.syncPlaybackRules(
        displaySeconds: displaySeconds,
        playbackMode: profile.playbackMode,
        durationType: durationType,
      );
    }
  }

  /// Pushes the global playback profile to the user's server profile.
  ///
  /// First tries `PUT /api/user/playback-rules` with the
  /// `{display_seconds, playback_mode, duration_type}` contract. If that
  /// endpoint is not reachable yet it degrades gracefully to the existing
  /// slideshow publish contract, which already persists interval/strategy/
  /// duration per frame.
  Future<void> pushProfileToFrame({
    required PairedFrame paired,
    required FramePlaybackProfile profile,
    String? userAuthToken,
  }) async {
    final mac = frameBleMacSlug(paired);
    final pairing = paired.resolvedPairingToken;
    final token = (userAuthToken ?? '').trim();

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    try {
      final res = await ApiClient(bearerToken: token.isEmpty ? null : token)
          .put(
            Uri.parse('${ApiConfig.baseUrl}/api/user/playback-rules'),
            headers: headers,
            body: jsonEncode({
              'display_seconds': profile.intervalMinutes * 60,
              'playback_mode': profile.playbackMode,
              'duration_type': profile.durationHours == 0
                  ? 'unlimited'
                  : '${profile.durationHours}h',
              'skip_play': true,
            }),
          )
          .timeout(const Duration(seconds: 12));
      if (res.statusCode >= 200 && res.statusCode < 300) return;
      AppDiagLog.verbose(
        '[FrameProfile] global endpoint ${res.statusCode} — using slideshow fallback',
      );
    } catch (e) {
      AppDiagLog.verbose('[FrameProfile] global push failed: $e');
    }

    // Fallback: re-apply the globals to the frame's current playlist so the
    // profile takes effect immediately (same server contract as the send UI).
    try {
      final stored = await SlideshowPlaylistStore.instance.load(paired);
      final ids = stored?.imageIds ?? const <String>[];
      if (ids.isNotEmpty) {
        await SlideshowRemoteApi(baseUrl: ApiConfig.baseUrl).publish(
          bearerToken: token.isEmpty ? null : token,
          pairingToken: pairing,
          macSlug: mac,
          imageIds: ids,
          intervalMinutes: profile.intervalMinutes,
          strategy: profile.strategy,
          durationHours: profile.durationHours,
          skipPlay: true,
        );
      }
    } catch (e) {
      AppDiagLog.verbose('[FrameProfile] slideshow fallback failed: $e');
    }
  }
}
