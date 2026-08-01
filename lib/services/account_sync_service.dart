import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../settings/app_settings.dart';
import 'device_store.dart';
import 'frame_mac_util.dart';
import 'send_albums_store.dart';

/// Bidirectional cloud sync: push local changes, pull only when server is newer.
class AccountSyncService {
  AccountSyncService._();
  static final instance = AccountSyncService._();

  static const _kTokenKey = 'settings_auth_token';
  static const _kSyncVersionKey = 'account_sync_version_v1';
  static const _kPrimaryFrameKey = 'account_primary_frame_id_v1';
  static const _kSettingsUpdatedAtKey = 'account_settings_updated_at_ms_v1';
  static const _kUnboundMacsKey = 'account_unbound_frame_macs_v1';

  Map<String, dynamic>? _lastProfile;
  Map<String, dynamic>? get lastProfile => _lastProfile;

  List<Map<String, dynamic>> _cachedPlaylistsMeta = [];
  List<Map<String, dynamic>> get cachedPlaylistsMeta =>
      List.unmodifiable(_cachedPlaylistsMeta);

  http.Client? _http;
  http.Client get _client => _http ??= http.Client();

  Timer? _pollTimer;
  Completer<void>? _syncLock;

  String get _apiBase => ApiConfig.baseUrl;

  void close() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _http?.close();
    _http = null;
  }

  /// Poll server every [interval] (default 2 minutes) while signed in.
  void startPeriodicSync({
    Duration interval = const Duration(seconds: 10),
    AppSettings? appSettings,
  }) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(interval, (_) {
      unawaited(syncAccountState(
        force: true,
        replaceFrames: true,
        appSettings: appSettings,
      ));
    });
  }

  void stopPeriodicSync() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<String> _authToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kTokenKey) ?? '';
  }

  Map<String, String> _headers(String token, {bool json = false}) => {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        if (json) 'Content-Type': 'application/json',
      };

  Future<int> localSyncVersion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kSyncVersionKey) ?? 0;
  }

  Future<void> _setLocalSyncVersion(int v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kSyncVersionKey, v);
  }

  Future<int> localSettingsUpdatedAt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kSettingsUpdatedAtKey) ?? 0;
  }

  Future<void> markLocalSettingsUpdated([int? atMs]) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _kSettingsUpdatedAtKey,
      atMs ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<void> _setLocalSettingsUpdatedAt(int atMs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kSettingsUpdatedAtKey, atMs);
  }

  /// Home pull-to-refresh: LWW settings + replace frames from server + gallery.
  Future<void> pullToRefresh({AppSettings? appSettings}) async {
    await syncAccountState(
      force: true,
      replaceFrames: true,
      appSettings: appSettings,
      reconcileSettingsLww: true,
    );
  }

  Future<void> hydrateAfterLogin(
    String authToken, {
    AppSettings? appSettings,
  }) async {
    // Fresh session: drop stale local frames, then take server as authority.
    await DeviceStore.instance.clear();
    await syncAccountState(
      force: true,
      authTokenOverride: authToken,
      replaceFrames: true,
      appSettings: appSettings,
    );
  }

  Future<T> _withSyncLock<T>(Future<T> Function() action) async {
    while (_syncLock != null) {
      await _syncLock!.future;
    }
    final gate = Completer<void>();
    _syncLock = gate;
    try {
      return await action();
    } finally {
      _syncLock = null;
      if (!gate.isCompleted) gate.complete();
    }
  }

  Future<Set<String>> _unboundMacs() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_kUnboundMacsKey) ?? const <String>[])
        .map((e) => e.trim().toUpperCase())
        .where((e) => e.isNotEmpty)
        .toSet();
  }

  Future<void> _rememberUnbound(String frameId) async {
    final slug =
        (FrameMacUtil.normalizeSlug(frameId) ?? frameId).trim().toUpperCase();
    if (slug.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final list = List<String>.from(prefs.getStringList(_kUnboundMacsKey) ?? const []);
    if (!list.contains(slug)) {
      list.insert(0, slug);
      await prefs.setStringList(_kUnboundMacsKey, list.take(100).toList());
    }
  }

  Future<void> _clearUnbound(String frameId) async {
    final slug =
        (FrameMacUtil.normalizeSlug(frameId) ?? frameId).trim().toUpperCase();
    if (slug.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final list = List<String>.from(prefs.getStringList(_kUnboundMacsKey) ?? const []);
    list.removeWhere((e) => e.toUpperCase() == slug);
    await prefs.setStringList(_kUnboundMacsKey, list);
  }

  /// Pull when server sync_version is strictly newer than local.
  /// Settings use last-write-wins via [sync_updated_at] vs local timestamp.
  Future<Map<String, dynamic>?> syncAccountState({
    bool force = false,
    bool replaceFrames = false,
    bool reconcileSettingsLww = true,
    String? authTokenOverride,
    AppSettings? appSettings,
  }) {
    return _withSyncLock(() async {
      try {
        final token = (authTokenOverride ?? await _authToken()).trim();
        if (token.isEmpty) return null;

        final uri = Uri.parse('$_apiBase/api/v1/user/profile');
        final res = await _client
            .get(uri, headers: _headers(token))
            .timeout(const Duration(seconds: 12));
        if (res.statusCode != 200) return null;

        final body = jsonDecode(res.body) as Map<String, dynamic>;
        if (body['ok'] != true) return null;

        final serverVersion = (body['sync_version'] as num?)?.toInt() ?? 0;
        final localVersion = await localSyncVersion();
        final serverNewer = serverVersion > localVersion;
        final serverUpdatedAt = (body['sync_updated_at'] as num?)?.toInt() ?? 0;
        final localUpdatedAt = await localSettingsUpdatedAt();

        await _downloadPendingTransit(
          (body['pending_transit'] as List?) ?? const [],
          token,
        );

        // Last-write-wins for settings: push local if it is newer than server.
        if (reconcileSettingsLww &&
            appSettings != null &&
            localUpdatedAt > 0 &&
            localUpdatedAt > serverUpdatedAt) {
          await pushPreferences(
            language: appSettings.languageCode,
            theme: appSettings.themeMode.name,
            clientUpdatedAt: localUpdatedAt,
          );
        }

        // Push local-only frames only when the server is not ahead and this is
        // not a forced pull — otherwise a deleted frame on another device would
        // get re-bound from a stale local copy.
        if (!replaceFrames && !force && !serverNewer) {
          await _pushLocalFramesMissingOnServer(
            (body['bound_frames'] as List?) ?? const [],
            token,
          );
        }

        if (!force && !serverNewer && !replaceFrames) {
          return body;
        }

        if (serverNewer || force || replaceFrames) {
          _lastProfile = body;

          final frames = (body['bound_frames'] as List?) ?? const [];
          final primary = (body['primary_frame_id'] as String?) ??
              (body['configurations'] is Map
                  ? (body['configurations'] as Map)['primary_frame_id'] as String?
                  : null);

          await DeviceStore.instance.applyBoundFramesFromServer(
            frames.cast<Map<String, dynamic>>(),
            primaryFrameId: primary,
            bearerToken: token,
            pruneMissing: replaceFrames || serverNewer || force,
          );

          if (primary != null && primary.trim().isNotEmpty) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_kPrimaryFrameKey, primary.trim());
          }

          final persisted = body['configurations_persisted'] == true;
          final configs = body['configurations'];
          final serverSettingsWin = serverUpdatedAt >= localUpdatedAt;
          if (persisted &&
              configs is Map &&
              appSettings != null &&
              (serverSettingsWin || replaceFrames) &&
              (serverNewer || force || replaceFrames)) {
            await appSettings.applyCloudConfigurations(
              Map<String, dynamic>.from(configs),
            );
            if (serverUpdatedAt > 0) {
              await _setLocalSettingsUpdatedAt(serverUpdatedAt);
            }
          }

          final playlists = (body['playlists_meta'] as List?) ?? const [];
          _cachedPlaylistsMeta = playlists
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          // AlbumCloudSync.syncAll merges with cloudIdToPath — don't wipe
          // local album paths here with metadata-only apply.

          if (serverVersion >= localVersion) {
            await _setLocalSyncVersion(serverVersion);
          }
        }

        return body;
      } catch (_) {
        return null;
      }
    });
  }

  Future<void> _pushLocalFramesMissingOnServer(
    List serverFrames,
    String token,
  ) async {
    await DeviceStore.instance.load();
    final serverKeys = <String>{};
    void addKey(String? raw) {
      final t = (raw ?? '').trim();
      if (t.isEmpty) return;
      final slug = FrameMacUtil.normalizeSlug(t)?.toUpperCase() ??
          t.toUpperCase().replaceAll(RegExp(r'[^0-9A-F]'), '');
      if (slug.isEmpty) return;
      serverKeys.add(slug);
      final asInt = int.tryParse(slug, radix: 16);
      if (asInt != null) {
        // Treat BLE/STA siblings as already bound.
        final sibMinus = (asInt - 2)
            .toRadixString(16)
            .toUpperCase()
            .padLeft(12, '0');
        final sibPlus = (asInt + 2)
            .toRadixString(16)
            .toUpperCase()
            .padLeft(12, '0');
        if (sibMinus.length == 12) serverKeys.add(sibMinus);
        if (sibPlus.length == 12) serverKeys.add(sibPlus);
      }
    }

    for (final f in serverFrames) {
      if (f is! Map) continue;
      addKey('${f['station_mac'] ?? ''}');
      addKey('${f['ble_mac'] ?? ''}');
      addKey('${f['frame_id'] ?? ''}');
    }

    final unbound = await _unboundMacs();
    for (final frame in DeviceStore.instance.pairedFrames) {
      // Never cloud-bind BLE-only / unnamed frames — other phones must not see them.
      if (!frame.isReadyForAccountSync) continue;
      final slug = FrameMacUtil.normalizeSlug(frame.deviceId)?.toUpperCase() ??
          frame.deviceId.trim().toUpperCase();
      if (slug.isEmpty) continue;
      if (serverKeys.contains(slug)) continue;
      if (unbound.contains(slug)) continue;
      // Also skip if any related unbound / server key exists.
      var related = false;
      final si = int.tryParse(slug, radix: 16);
      if (si != null) {
        for (final k in [...serverKeys, ...unbound]) {
          final ki = int.tryParse(k, radix: 16);
          if (ki != null && (ki - si).abs() == 2) {
            related = true;
            break;
          }
        }
      }
      if (related) continue;
      await pushBoundFrame(
        slug,
        setPrimary: false,
        authTokenOverride: token,
        frameName: frame.frameName,
        wifiSsid: frame.wifiSsid,
      );
    }
  }

  /// Push language/theme/primary to server and advance sync_version.
  Future<bool> pushPreferences({
    String? language,
    String? theme,
    String? primaryFrameId,
    bool? pushNotificationsEnabled,
    Map<String, dynamic>? displayPreferences,
    int? clientUpdatedAt,
  }) async {
    final token = await _authToken();
    if (token.isEmpty) return false;
    try {
      final at = clientUpdatedAt ?? DateTime.now().millisecondsSinceEpoch;
      await markLocalSettingsUpdated(at);

      final body = <String, dynamic>{
        'client_updated_at': at,
      };
      if (language != null) body['language'] = language;
      if (theme != null) body['theme'] = theme;
      if (primaryFrameId != null) body['primary_frame_id'] = primaryFrameId;
      if (pushNotificationsEnabled != null) {
        body['push_notifications_enabled'] = pushNotificationsEnabled;
      }
      if (displayPreferences != null) {
        body['display_preferences'] = displayPreferences;
      }
      if (body.length <= 1) return false; // only client_updated_at

      final uri = Uri.parse('$_apiBase/api/v1/user/profile');
      final res = await _client
          .put(
            uri,
            headers: _headers(token, json: true),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return false;
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      if (json['ok'] != true) return false;
      if (json['ignored'] == true) {
        // Server has newer settings — adopt server timestamp.
        final serverAt = (json['sync_updated_at'] as num?)?.toInt();
        if (serverAt != null) await _setLocalSettingsUpdatedAt(serverAt);
        return false;
      }
      final v = (json['sync_version'] as num?)?.toInt();
      if (v != null) await _setLocalSyncVersion(v);
      final serverAt = (json['sync_updated_at'] as num?)?.toInt();
      if (serverAt != null) await _setLocalSettingsUpdatedAt(serverAt);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Bind a frame MAC to this account on the server (makes it visible on other devices).
  Future<bool> pushBoundFrame(
    String macOrId, {
    bool setPrimary = true,
    String? authTokenOverride,
    String? frameName,
    String? wifiSsid,
  }) async {
    final token = (authTokenOverride ?? await _authToken()).trim();
    if (token.isEmpty) return false;
    final slug = FrameMacUtil.normalizeSlug(macOrId);
    if (slug == null || slug.length != 12) return false;
    try {
      final uri = Uri.parse('$_apiBase/api/v1/user/frames/bind');
      final body = <String, dynamic>{
        'ble_mac': slug,
        'set_primary': setPrimary,
      };
      final name = frameName?.trim();
      if (name != null && name.isNotEmpty) body['frame_name'] = name;
      final ssid = wifiSsid?.trim();
      if (ssid != null && ssid.isNotEmpty) body['wifi_ssid'] = ssid;
      final res = await _client
          .post(
            uri,
            headers: _headers(token, json: true),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return false;
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      if (json['ok'] != true) return false;
      await _clearUnbound(slug);
      final v = (json['sync_version'] as num?)?.toInt();
      if (v != null) await _setLocalSyncVersion(v);
      final primary = json['primary_frame_id']?.toString();
      if (primary != null && primary.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_kPrimaryFrameKey, primary);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _downloadPendingTransit(List raw, String token) async {
    if (raw.isEmpty) return;
    Directory? dir;
    try {
      dir = await getApplicationSupportDirectory();
    } catch (_) {
      return;
    }
    final transitDir = Directory(p.join(dir.path, 'transit_cache'));
    if (!await transitDir.exists()) {
      await transitDir.create(recursive: true);
    }

    for (final item in raw) {
      if (item is! Map) continue;
      final id = '${item['package_id'] ?? ''}'.trim();
      if (id.isEmpty) continue;
      final pathSuffix = '${item['download_path'] ?? '/api/v1/sync/transit/$id'}';
      final filename =
          '${item['filename'] ?? id}'.replaceAll(RegExp(r'[^\w.\-]'), '_');
      try {
        final uri = Uri.parse('$_apiBase$pathSuffix');
        final res = await _client
            .get(uri, headers: _headers(token))
            .timeout(const Duration(seconds: 60));
        if (res.statusCode != 200 || res.bodyBytes.isEmpty) continue;
        final out = File(p.join(transitDir.path, '${id}_$filename'));
        await out.writeAsBytes(res.bodyBytes, flush: true);
      } catch (_) {}
    }
  }

  Future<String?> uploadTransitFile(File file, {String? label}) async {
    final token = await _authToken();
    if (token.isEmpty || !await file.exists()) return null;
    try {
      final uri = Uri.parse('$_apiBase/api/v1/sync/transit');
      final req = http.MultipartRequest('POST', uri);
      req.headers.addAll(_headers(token));
      req.files.add(await http.MultipartFile.fromPath('file', file.path));
      if (label != null && label.isNotEmpty) req.fields['label'] = label;
      final streamed = await req.send().timeout(const Duration(seconds: 60));
      final body = await streamed.stream.bytesToString();
      if (streamed.statusCode < 200 || streamed.statusCode >= 300) return null;
      final json = jsonDecode(body) as Map<String, dynamic>;
      if (json['ok'] != true) return null;
      return json['package_id']?.toString();
    } catch (_) {
      return null;
    }
  }

  /// Unbind frame on the server, drop it locally, and pull server as authority.
  Future<bool> deleteFrame(String frameId) async {
    final token = await _authToken();
    final slug =
        (FrameMacUtil.normalizeSlug(frameId) ?? frameId).trim().toUpperCase();
    if (slug.isEmpty) return false;

    // Unbind BLE + STA siblings so the other phone cannot rehydrate a double.
    final siblings = <String>{slug};
    final asInt = int.tryParse(slug, radix: 16);
    if (asInt != null) {
      final minus = (asInt - 2).toRadixString(16).toUpperCase().padLeft(12, '0');
      final plus = (asInt + 2).toRadixString(16).toUpperCase().padLeft(12, '0');
      if (minus.length == 12) siblings.add(minus);
      if (plus.length == 12) siblings.add(plus);
    }

    for (final id in siblings) {
      await _rememberUnbound(id);
      try {
        await DeviceStore.instance.forgetPairedFrame(id);
      } catch (_) {}
    }

    if (token.isEmpty) return true;
    var anyOk = false;
    try {
      for (final id in siblings) {
        final uri = Uri.parse(
          '$_apiBase/api/v1/user/frames/${Uri.encodeComponent(id)}/unbind',
        );
        final res = await _client
            .post(uri, headers: _headers(token))
            .timeout(const Duration(seconds: 12));
        if (res.statusCode == 200) anyOk = true;
      }
      await syncAccountState(force: true, replaceFrames: true);
      return anyOk;
    } catch (_) {
      return false;
    }
  }

  Future<void> afterUpload() async {
    await syncAccountState();
  }

  Future<void> wipeLocalSyncState() async {
    stopPeriodicSync();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kSyncVersionKey);
    await prefs.remove(_kPrimaryFrameKey);
    await prefs.remove(_kSettingsUpdatedAtKey);
    await prefs.remove(_kUnboundMacsKey);
    _lastProfile = null;
    _cachedPlaylistsMeta = [];
    try {
      final dir = await getApplicationSupportDirectory();
      final transitDir = Directory(p.join(dir.path, 'transit_cache'));
      if (await transitDir.exists()) {
        await transitDir.delete(recursive: true);
      }
    } catch (_) {}
  }
}
