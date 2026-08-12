import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../settings/app_settings.dart';
import 'api_client.dart';
import 'auth_session_manager.dart';
import 'app_diag_log.dart';
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

  /// Shared authenticated client with the global 401 interceptor.
  final _api = ApiClient();

  Timer? _pollTimer;
  Completer<void>? _syncLock;

  String get _apiBase => ApiConfig.baseUrl;

  void close() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _api.close();
  }

  /// Poll server every [interval] (default 2 minutes) while signed in.
  void startPeriodicSync({
    Duration interval = const Duration(minutes: 2),
    AppSettings? appSettings,
  }) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(interval, (_) {
      unawaited(syncAccountState(
        force: false,
        replaceFrames: false,
        pruneMissingFrames: false,
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

  /// Home pull-to-refresh: LWW settings + merge frames (never wipe local pairing).
  Future<void> pullToRefresh({AppSettings? appSettings}) async {
    await syncAccountState(
      force: true,
      replaceFrames: true,
      pruneMissingFrames: false,
      appSettings: appSettings,
      reconcileSettingsLww: true,
    );
  }

  Future<void> hydrateAfterLogin(
    String authToken, {
    AppSettings? appSettings,
  }) async {
    // Keep any local wall-frame pairing on this phone. Merge server frames on
    // top — never DeviceStore.clear() here (that forced users to re-pair).
    await DeviceStore.instance.load();
    await syncAccountState(
      force: true,
      authTokenOverride: authToken,
      replaceFrames: true,
      pruneMissingFrames: false,
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
    final drop = <String>{slug};
    final si = int.tryParse(slug, radix: 16);
    if (si != null) {
      final minus =
          (si - 2).toRadixString(16).toUpperCase().padLeft(12, '0');
      final plus =
          (si + 2).toRadixString(16).toUpperCase().padLeft(12, '0');
      if (minus.length == 12) drop.add(minus);
      if (plus.length == 12) drop.add(plus);
    }
    list.removeWhere((e) => drop.contains(e.toUpperCase()));
    await prefs.setStringList(_kUnboundMacsKey, list);
  }

  /// Cloud re-granted access (family invite / re-share / re-bind). Drop local
  /// delete bans for those MACs so Home can show the shared frame again.
  Future<void> clearUnboundBansForCloudFrames(
    Iterable<Map<String, dynamic>> frames,
  ) async {
    for (final f in frames) {
      for (final k in [
        f['frame_id'],
        f['ble_mac'],
        f['station_mac'],
        f['id'],
        f['bleMac'],
        f['stationMac'],
      ]) {
        final raw = k?.toString().trim() ?? '';
        if (raw.isNotEmpty) await _clearUnbound(raw);
      }
    }
  }

  /// True when [raw] matches a MAC the user explicitly deleted (incl. BLE/STA ±2).
  Future<bool> isUnboundFrameId(String? raw) async {
    final slug = FrameMacUtil.normalizeSlug(raw ?? '')?.toUpperCase() ??
        (raw ?? '').trim().toUpperCase();
    if (slug.isEmpty) return false;
    final unbound = await _unboundMacs();
    if (unbound.contains(slug)) return true;
    final si = int.tryParse(slug, radix: 16);
    if (si == null) return false;
    for (final k in unbound) {
      final ki = int.tryParse(k, radix: 16);
      if (ki != null && (ki - si).abs() == 2) return true;
    }
    return false;
  }

  /// Drop frames the user deleted so pull/sync cannot resurrect them —
  /// unless the cloud is actively listing them again (family invite / re-share).
  Future<List<Map<String, dynamic>>> filterOutUnboundFrames(
    List<Map<String, dynamic>> frames,
  ) async {
    if (frames.isEmpty) return frames;
    // Authenticated cloud list is the source of truth for current access.
    // A prior local Remove must not permanently block a later family invite.
    await clearUnboundBansForCloudFrames(frames);
    return frames;
  }

  /// Pull when server sync_version is strictly newer than local.
  /// Settings use last-write-wins via [sync_updated_at] vs local timestamp.
  ///
  /// [pruneMissingFrames] overrides whether local frames absent from the server
  /// list are removed. Pass `false` after family join so a partial profile
  /// response cannot wipe frames that [DeviceStore.syncServerFrames] just added.
  Future<Map<String, dynamic>?> syncAccountState({
    bool force = false,
    bool replaceFrames = false,
    bool reconcileSettingsLww = true,
    bool? pruneMissingFrames,
    String? authTokenOverride,
    AppSettings? appSettings,
  }) {
    return _withSyncLock(() async {
      try {
        final token = (authTokenOverride ?? await _authToken()).trim();
        if (token.isEmpty) return null;

        final uri = Uri.parse('$_apiBase/api/v1/user/profile');
        final res = await _api
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

        // Always push local wall frames that the cloud is missing — even when
        // server sync_version is ahead — so an empty bound_frames list cannot
        // leave this phone as the only copy with no cloud backup.
        await _pushLocalFramesMissingOnServer(
          (body['bound_frames'] as List?) ?? const [],
          token,
        );

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

          final cast = frames
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(
                    e.map((k, v) => MapEntry(k.toString(), v)),
                  ))
              .toList();
          final filtered = await filterOutUnboundFrames(cast);

          await DeviceStore.instance.applyBoundFramesFromServer(
            filtered,
            primaryFrameId: primary,
            bearerToken: token,
            // Sticky pairing: never prune locals from an empty/partial list.
            pruneMissing: pruneMissingFrames ?? false,
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
      final res = await _api
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
      final res = await _api
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
        final res = await _api
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
      final res = await _api.send(req).timeout(const Duration(seconds: 60));
      if (res.statusCode < 200 || res.statusCode >= 300) return null;
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      if (json['ok'] != true) return null;
      return json['package_id']?.toString();
    } catch (_) {
      return null;
    }
  }

  /// Unbind frame on the server, drop it locally, and pull server as authority.
  ///
  /// Owner / family-owner delete must not come back via the next Home sync.
  Future<bool> deleteFrame(String frameId) async {
    final token = await _authToken();
    final raw = frameId.trim();
    final slug =
        (FrameMacUtil.normalizeSlug(raw) ?? raw).trim().toUpperCase();
    if (slug.isEmpty && raw.isEmpty) return false;

    // Unbind BLE + STA siblings so the other phone cannot rehydrate a double.
    final siblings = <String>{};
    if (slug.isNotEmpty) siblings.add(slug);
    if (raw.isNotEmpty) {
      final rawSlug =
          (FrameMacUtil.normalizeSlug(raw) ?? raw).trim().toUpperCase();
      if (rawSlug.isNotEmpty) siblings.add(rawSlug);
    }
    final asInt = int.tryParse(slug.isNotEmpty ? slug : raw, radix: 16);
    if (asInt != null) {
      final minus = (asInt - 2).toRadixString(16).toUpperCase().padLeft(12, '0');
      final plus = (asInt + 2).toRadixString(16).toUpperCase().padLeft(12, '0');
      if (minus.length == 12) siblings.add(minus);
      if (plus.length == 12) siblings.add(plus);
    }

    // Ban first so concurrent syncServerFrames cannot resurrect the row.
    for (final id in siblings) {
      await _rememberUnbound(id);
    }

    // Always clear local Home list (exact + related ids).
    try {
      await DeviceStore.instance.forgetPairedFrame(raw.isNotEmpty ? raw : slug);
    } catch (_) {}
    for (final id in siblings) {
      try {
        await DeviceStore.instance.forgetPairedFrame(id);
      } catch (_) {}
    }

    if (token.isEmpty) return true;

    var anyOk = false;
    AuthSessionManager.instance.suppressUnauthorizedHandling(true);
    try {
      for (final id in siblings) {
        final uri = Uri.parse(
          '$_apiBase/api/v1/user/frames/${Uri.encodeComponent(id)}/unbind',
        );
        final res = await _api
            .post(uri, headers: _headers(token))
            .timeout(const Duration(seconds: 12));
        if (res.statusCode == 200) {
          anyOk = true;
        } else {
          AppDiagLog.verbose(
            '[account-sync] unbind $id -> HTTP ${res.statusCode} ${res.body}',
          );
        }
      }
      // Pull with prune, but unbound filter blocks resurrection if server lags.
      await syncAccountState(
        force: true,
        replaceFrames: true,
        pruneMissingFrames: true,
        authTokenOverride: token,
      );
      // Final local sweep — sync must not have brought it back.
      for (final id in siblings) {
        try {
          await DeviceStore.instance.forgetPairedFrame(id);
        } catch (_) {}
      }
      try {
        await DeviceStore.instance.forgetPairedFrame(raw.isNotEmpty ? raw : slug);
      } catch (_) {}
      return anyOk;
    } catch (e, st) {
      AppDiagLog.verbose('[account-sync] deleteFrame failed: $e\n$st');
      // Local delete still succeeded; keep unbound ban.
      return true;
    } finally {
      AuthSessionManager.instance.suppressUnauthorizedHandling(false);
    }
  }

  Future<void> afterUpload() async {
    await syncAccountState();
  }

  /// Manual physical re-pairing wins ownership: drop any local unbound bans
  /// (self + BLE/STA ±2 siblings) so Home sync no longer filters the frame,
  /// tell the server to reassign the owner on this hardware, and force a resync
  /// that re-pushes the bind. Must be called only after Wi‑Fi is confirmed.
  ///
  /// Backend contract for `POST {base}/api/frames/pair`:
  /// body `{ "ble_mac": slug, "set_primary": true }` → if the record exists,
  /// set `owner_account` to the requesting user immediately and clear any
  /// stale owner/unbound reference from a previous account so re-pairing works
  /// without logging out. Return `200 {"ok":true}` on success.
  Future<void> grantOwnerForManualPair(String frameId) async {
    final token = await _authToken();
    final raw = frameId.trim();
    final slug =
        (FrameMacUtil.normalizeSlug(raw) ?? raw).trim().toUpperCase();
    if (slug.isEmpty) return;

    // Clear the un-posted ban for this MAC and its ±2 MAC siblings first,
    // so Home sync does not filter the freshly paired frame before it binds.
    await _clearUnbound(slug);
    final asInt = int.tryParse(slug, radix: 16);
    if (asInt != null) {
      for (final delta in const [-2, 2]) {
        final s =
            (asInt + delta).toRadixString(16).toUpperCase().padLeft(12, '0');
        if (s.length == 12) await _clearUnbound(s);
      }
    }

    if (token.isEmpty) return;

    try {
      final uri = Uri.parse('$_apiBase/api/frames/pair');
      final res = await _api
          .post(
            uri,
            headers: _headers(token, json: true),
            body: jsonEncode({'ble_mac': slug, 'set_primary': true}),
          )
          .timeout(const Duration(seconds: 12));
      AppDiagLog.verbose(
        '[account-sync] grantOwner manual pair $slug -> HTTP ${res.statusCode} ${res.body}',
      );
      if (res.statusCode == 200 ||
          (res.body.isNotEmpty && res.body.contains('"ok":true'))) {
        await _clearUnbound(slug);
      }
    } catch (e) {
      // Endpoint not deployed yet — fall through to the normal bind re-push.
      AppDiagLog.verbose('[account-sync] grantOwner pair endpoint skipped: $e');
    }

    // Re-push the bind for the crowd path (also clears the ban on success).
    // Callers fire-and-forget this method, so awaiting here keeps the resync's
    // own error handling (returns null on failure) instead of an unhandled
    // async error escaping an unawaited future.
    await syncAccountState(
      force: true,
      pruneMissingFrames: false,
      authTokenOverride: token,
    );
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
