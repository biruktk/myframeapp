import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'device_store.dart';
import 'frame_mac_util.dart';

/// Unified cloud ↔ local sync for frames, uploads, and albums.
///
/// Called after every successful login and on every app-resume so that
/// changes made on any platform (Flutter iOS/Android, WeChat Mini-Program)
/// are reflected everywhere under the same account.
class AccountSyncService {
  AccountSyncService._();
  static final instance = AccountSyncService._();

  static const _kApiBase = 'https://myframe.ink';
  static const _kTokenKey = 'settings_auth_token';

  /// Cached result of the last successful profile sync.
  Map<String, dynamic>? _lastProfile;
  Map<String, dynamic>? get lastProfile => _lastProfile;

  /// Cached media list from the last successful media sync.
  List<Map<String, dynamic>> _cachedMedia = [];
  List<Map<String, dynamic>> get cachedMedia =>
      List.unmodifiable(_cachedMedia);

  /// Cached albums list from the last successful albums sync.
  List<Map<String, dynamic>> _cachedAlbums = [];
  List<Map<String, dynamic>> get cachedAlbums =>
      List.unmodifiable(_cachedAlbums);

  http.Client? _http;
  http.Client get _client => _http ??= http.Client();

  void close() {
    _http?.close();
    _http = null;
  }

  Future<String> _authToken() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kTokenKey) ?? '';
  }

  Map<String, String> _headers(String token) => {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      };

  // ---------------------------------------------------------------------------
  // Frame sync
  // ---------------------------------------------------------------------------

  /// Fetch unified profile from `GET /api/v1/user/profile` and apply the
  /// complete bound-frame list (not just the first one) to [DeviceStore].
  Future<Map<String, dynamic>?> syncAccountState() async {
    final token = await _authToken();
    if (token.isEmpty) return null;

    try {
      final uri = Uri.parse('$_kApiBase/api/v1/user/profile');
      final res = await _client
          .get(uri, headers: _headers(token))
          .timeout(const Duration(seconds: 12));

      if (res.statusCode != 200) return null;

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['ok'] != true) return null;

      _lastProfile = body;

      // Restore the FULL list of bound frames, not just frames[0].
      final frames = (body['bound_frames'] as List?) ?? [];
      if (frames.isNotEmpty) {
        await _applyServerFrames(
            frames.cast<Map<String, dynamic>>(), token);
      }

      // Cache uploads from profile (small mirror of fetchUserMedia).
      final uploads = (body['user_uploads'] as List?) ?? [];
      if (uploads.isNotEmpty) {
        _cachedMedia = uploads.cast<Map<String, dynamic>>();
      }

      return body;
    } catch (_) {
      return null;
    }
  }

  /// Applies the full server-side frame list to [DeviceStore], preserving any
  /// locally-paired frames and merging in cloud-only frames.
  Future<void> _applyServerFrames(
    List<Map<String, dynamic>> serverFrames,
    String token,
  ) async {
    final store = DeviceStore.instance;
    await store.load();

    for (final f in serverFrames) {
      final mac = (f['ble_mac'] as String?) ?? '';
      final frameId = (f['frame_id'] as String?) ?? '';
      final rawId = mac.isNotEmpty ? mac : frameId;
      if (rawId.isEmpty) continue;

      final slug = FrameMacUtil.normalizeSlug(rawId) ?? rawId;

      // If this frame is not already in the local list, add it as a server frame.
      final alreadyLocal = store.pairedFrames
          .any((lf) => lf.deviceId.trim().toUpperCase() == slug.toUpperCase());

      if (!alreadyLocal) {
        // Register as a minimal PairedFrame so the Home screen can display it.
        await store.saveManualPairing(
          deviceId: slug,
          bleNamePrefix: f['frame_name']?.toString(),
        );
      }

      // Always keep the MAC slot fresh so API calls hit the right endpoint.
      await store.savePairedFrameMac(slug);
    }

    // Push the full server list into _serverFrames for the family/server view.
    await store.syncServerFrames(bearerToken: token);
  }

  // ---------------------------------------------------------------------------
  // Media (personal uploads) sync
  // ---------------------------------------------------------------------------

  /// Fetch the user's personal upload history from `GET /api/v1/user/media`.
  ///
  /// Returns an ordered list of upload records (newest first).
  /// Falls back to `GET /api/user/gallery` for servers that only implement
  /// the older endpoint, ensuring backward compatibility.
  Future<List<Map<String, dynamic>>> fetchUserMedia() async {
    final token = await _authToken();
    if (token.isEmpty) return const [];

    // Try the canonical v1 endpoint first.
    try {
      final uri = Uri.parse('$_kApiBase/api/v1/user/media');
      final res = await _client
          .get(uri, headers: _headers(token))
          .timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        if (body['ok'] == true) {
          final raw = (body['media'] ?? body['photos'] ?? body['items']) as List?;
          if (raw != null && raw.isNotEmpty) {
            _cachedMedia = raw.cast<Map<String, dynamic>>();
            return _cachedMedia;
          }
        }
      }
    } catch (_) {}

    // Fallback: legacy /api/user/gallery (existing backend route).
    try {
      final uri = Uri.parse('$_kApiBase/api/user/gallery');
      final res = await _client
          .get(uri, headers: _headers(token))
          .timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final raw = (body['photos'] ?? body['items']) as List?;
        if (raw != null && raw.isNotEmpty) {
          _cachedMedia = raw.cast<Map<String, dynamic>>();
          return _cachedMedia;
        }
      }
    } catch (_) {}

    return const [];
  }

  // ---------------------------------------------------------------------------
  // Albums sync
  // ---------------------------------------------------------------------------

  /// Fetch the user's created photo albums from `GET /api/v1/user/albums`.
  ///
  /// Returns an ordered list of album records. Each record contains at minimum:
  ///   `id`, `name`, `frame_id`, `photo_count`, `cover_url`, `created_at`.
  Future<List<Map<String, dynamic>>> fetchUserAlbums() async {
    final token = await _authToken();
    if (token.isEmpty) return const [];

    try {
      final uri = Uri.parse('$_kApiBase/api/v1/user/albums');
      final res = await _client
          .get(uri, headers: _headers(token))
          .timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        if (body['ok'] == true) {
          final raw =
              (body['albums'] ?? body['items']) as List?;
          if (raw != null) {
            _cachedAlbums = raw.cast<Map<String, dynamic>>();
            return _cachedAlbums;
          }
        }
      }
    } catch (_) {}

    return const [];
  }

  // ---------------------------------------------------------------------------
  // Convenience: full post-login hydration
  // ---------------------------------------------------------------------------

  /// Full sync immediately after a successful auth session.
  /// Runs frames, media, and albums in parallel for speed.
  Future<void> hydrateAfterLogin(String authToken) async {
    await Future.wait([
      syncAccountState(),
      fetchUserMedia(),
      fetchUserAlbums(),
    ]);
  }

  // ---------------------------------------------------------------------------
  // Frame unbind
  // ---------------------------------------------------------------------------

  /// Delete a frame on the server and sync the updated frame list locally.
  Future<bool> deleteFrame(String frameId) async {
    final token = await _authToken();
    if (token.isEmpty) return false;

    try {
      final uri =
          Uri.parse('$_kApiBase/api/v1/user/frames/$frameId/unbind');
      final res = await _client
          .post(uri, headers: _headers(token))
          .timeout(const Duration(seconds: 12));

      if (res.statusCode != 200) return false;

      await syncAccountState();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Called after a local photo upload to refresh the upload list from server.
  Future<void> afterUpload() async {
    await syncAccountState();
  }
}
