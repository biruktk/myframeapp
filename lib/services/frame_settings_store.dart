import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../models/frame_playback_profile.dart';
import 'app_diag_log.dart';
import 'api_client.dart';
import 'device_store.dart';
import 'frame_ble_mac_slug.dart';
import 'local_storage_service.dart';
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

  Future<void> save(PairedFrame? paired, FramePlaybackProfile profile) async {
    _active = profile;
    try {
      final key = await _key(paired);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, jsonEncode(profile.toJson()));
    } catch (e, st) {
      AppDiagLog.verbose('[FrameSettingsStore] save failed: $e\n$st');
    }
  }

  /// Pushes the global playback profile to the frame's server profile.
  ///
  /// First tries the frame-settings payload
  /// `{global_interval, global_playback_mode, global_duration}` on
  /// `PUT /api/frames/{mac}/settings`. If that endpoint is not deployed yet it
  /// degrades gracefully to the existing slideshow publish contract, which
  /// already persists interval/strategy/duration per frame.
  Future<void> pushProfileToFrame({
    required PairedFrame paired,
    required FramePlaybackProfile profile,
    String? userAuthToken,
  }) async {
    final mac = frameBleMacSlug(paired);
    final encoded = Uri.encodeComponent(mac);
    final base = paired.resolvedApiBaseUrl ?? ApiConfig.baseUrl;
    final pairing = paired.resolvedPairingToken;
    final token = (userAuthToken ?? '').trim();

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (pairing != null && pairing.isNotEmpty) {
      headers['x-pairing-token'] = pairing;
    }

    try {
      final res = await ApiClient(bearerToken: token.isEmpty ? null : token)
          .put(
            Uri.parse('$base/api/frames/$encoded/settings'),
            headers: headers,
            body: jsonEncode(profile.toFrameSettingsPayload()),
          )
          .timeout(const Duration(seconds: 12));
      if (res.statusCode >= 200 && res.statusCode < 300) return;
      AppDiagLog.verbose(
        '[FrameProfile] settings endpoint ${res.statusCode} — using slideshow fallback',
      );
    } catch (e) {
      AppDiagLog.verbose('[FrameProfile] settings push failed: $e');
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
