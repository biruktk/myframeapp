import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import 'gallery_image_cache.dart';
import 'personal_gallery_store.dart';
import 'app_diag_log.dart';

class CloudGalleryPhoto {
  const CloudGalleryPhoto({
    required this.id,
    required this.url,
    required this.atMs,
    this.deviceId,
  });

  final String id;
  final String url;
  final int atMs;
  final String? deviceId;

  factory CloudGalleryPhoto.fromJson(Map<String, dynamic> j) {
    return CloudGalleryPhoto(
      id: '${j['id'] ?? ''}',
      url: '${j['url'] ?? ''}',
      atMs: (j['atMs'] as num?)?.toInt() ??
          (j['at_ms'] as num?)?.toInt() ??
          0,
      deviceId: (j['deviceId'] ?? j['device_id'])?.toString(),
    );
  }
}

/// Syncs the personal gallery with VPS (`GET/POST /api/user/gallery`).
class UserGalleryCloudService {
  UserGalleryCloudService._();
  static final UserGalleryCloudService instance = UserGalleryCloudService._();

  static const _requestTimeout = Duration(seconds: 20);
  static const _uploadTimeout = Duration(seconds: 45);
  static const _syncOverallTimeout = Duration(seconds: 45);
  static const _kSyncedIds = 'personal_gallery_cloud_ids_v1';
  static const _kDeletedIds = 'personal_gallery_deleted_ids_v1';

  Future<void>? _inFlight;
  var _rerunRequested = false;
  var _rerunUploadLocalFirst = true;
  String? _rerunDeviceId;
  String? _rerunToken;

  Uri _uri(String path) {
    final base = ApiConfig.baseUrl.replaceAll(RegExp(r'/+$'), '');
    final pth = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$base$pth');
  }

  Map<String, String> _authHeaders(String token) => {
        'Accept': 'application/json',
        'Authorization': 'Bearer ${token.trim()}',
      };

  Future<Map<String, String>> _loadIdToPath() async {
    final prefs = await SharedPreferences.getInstance();
    final rawMeta = prefs.getString(_kSyncedIds);
    if (rawMeta == null || rawMeta.isEmpty) return {};
    try {
      final m = jsonDecode(rawMeta) as Map<String, dynamic>;
      return m.map((k, v) => MapEntry(k, '$v'));
    } catch (_) {
      return {};
    }
  }

  Future<void> _saveIdToPath(Map<String, String> idToPath) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSyncedIds, jsonEncode(idToPath));
  }

  Future<List<CloudGalleryPhoto>> fetchPhotos(String authToken) async {
    final tok = authToken.trim();
    if (tok.isEmpty) return const [];
    try {
      var res = await http
          .get(_uri('/api/user/gallery'), headers: _authHeaders(tok))
          .timeout(_requestTimeout);
      if (res.statusCode != 200) {
        res = await http
            .get(_uri('/api/v1/user/media'), headers: _authHeaders(tok))
            .timeout(_requestTimeout);
      }
      if (res.statusCode != 200) {
        AppDiagLog.verbose('[UserGallery] fetch ${res.statusCode} ${res.body}');
        return const [];
      }
      final map = jsonDecode(res.body) as Map<String, dynamic>;
      if (map['ok'] == false) return const [];
      final raw = map['photos'] ?? map['media'] ?? map['items'];
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) => CloudGalleryPhoto.fromJson(Map<String, dynamic>.from(e)))
          .where((e) => e.id.isNotEmpty && e.url.isNotEmpty)
          .toList();
    } catch (e, st) {
      AppDiagLog.verbose('[UserGallery] fetch failed: $e\n$st');
      return const [];
    }
  }

  /// Uploads a local file and returns the cloud photo id when available.
  Future<String?> uploadFile({
    required String authToken,
    required String localPath,
    String? deviceId,
  }) async {
    final tok = authToken.trim();
    if (tok.isEmpty) return null;
    final file = File(localPath);
    if (!await file.exists()) return null;
    try {
      final req = http.MultipartRequest('POST', _uri('/api/user/gallery'))
        ..headers.addAll(_authHeaders(tok))
        ..files.add(await http.MultipartFile.fromPath('file', localPath))
        ..fields.addAll({
          if (deviceId != null && deviceId.trim().isNotEmpty)
            'device_id': deviceId.trim(),
        });
      final streamed = await req.send().timeout(_uploadTimeout);
      final body = await streamed.stream.bytesToString();
      if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
        AppDiagLog.verbose('[UserGallery] upload ${streamed.statusCode} $body');
        return null;
      }
      try {
        final map = jsonDecode(body) as Map<String, dynamic>;
        final id = '${map['id'] ?? map['photo_id'] ?? map['media_id'] ?? ''}';
        if (id.isNotEmpty) {
          final idToPath = await _loadIdToPath();
          idToPath[id] = localPath;
          await _saveIdToPath(idToPath);
          return id;
        }
        final photo = map['photo'];
        if (photo is Map) {
          final pid = '${photo['id'] ?? ''}';
          if (pid.isNotEmpty) {
            final idToPath = await _loadIdToPath();
            idToPath[pid] = localPath;
            await _saveIdToPath(idToPath);
            return pid;
          }
        }
      } catch (_) {}
      return null;
    } catch (e, st) {
      AppDiagLog.verbose('[UserGallery] upload failed: $e\n$st');
      return null;
    }
  }

  /// Push local-only gallery files that are not yet mapped to a cloud id.
  Future<void> uploadLocalOnly({
    required String authToken,
    String? deviceId,
    int maxUploads = 12,
  }) async {
    final tok = authToken.trim();
    if (tok.isEmpty) return;
    await PersonalGalleryStore.instance.load();
    final idToPath = await _loadIdToPath();
    final knownPaths = idToPath.values.toSet();
    var uploaded = 0;
    for (final path in PersonalGalleryStore.instance.paths) {
      if (uploaded >= maxUploads) break;
      if (knownPaths.contains(path)) continue;
      if (!await File(path).exists()) continue;
      final id = await uploadFile(
        authToken: tok,
        localPath: path,
        deviceId: deviceId,
      );
      if (id != null) {
        uploaded++;
        knownPaths.add(path);
      }
    }
    if (uploaded > 0) {
      AppDiagLog.verbose('[UserGallery] uploaded $uploaded local-only photo(s)');
    }
  }

  /// Downloads cloud photos and merges into [PersonalGalleryStore] (newest first).
  /// Skips any IDs in the local tombstone list (deleted on this or another client).
  /// When [uploadLocalFirst] is true, pushes a limited batch of unmapped locals
  /// after download so pull-to-refresh cannot hang forever uploading.
  Future<void> syncFromServer(
    String authToken, {
    bool uploadLocalFirst = true,
    String? deviceId,
  }) async {
    final tok = authToken.trim();
    if (tok.isEmpty) return;

    // Queue a follow-up instead of dropping concurrent sync requests.
    if (_inFlight != null) {
      _rerunRequested = true;
      _rerunToken = tok;
      _rerunDeviceId = deviceId;
      _rerunUploadLocalFirst = _rerunUploadLocalFirst || uploadLocalFirst;
      return _inFlight!;
    }

    final run = () async {
      try {
        await _syncOnce(
          tok,
          uploadLocalFirst: uploadLocalFirst,
          deviceId: deviceId,
        ).timeout(_syncOverallTimeout);
      } on TimeoutException {
        AppDiagLog.verbose('[UserGallery] sync timed out');
      } catch (e, st) {
        AppDiagLog.verbose('[UserGallery] sync failed: $e\n$st');
      }
    }();

    _inFlight = run;
    try {
      await run;
    } finally {
      _inFlight = null;
      if (_rerunRequested) {
        _rerunRequested = false;
        final nextTok = _rerunToken ?? tok;
        final nextUpload = _rerunUploadLocalFirst;
        final nextDevice = _rerunDeviceId;
        _rerunUploadLocalFirst = true;
        _rerunDeviceId = null;
        _rerunToken = null;
        unawaited(
          syncFromServer(
            nextTok,
            uploadLocalFirst: nextUpload,
            deviceId: nextDevice,
          ),
        );
      }
    }
  }

  Future<void> _syncOnce(
    String tok, {
    required bool uploadLocalFirst,
    String? deviceId,
  }) async {
    // Download first so the other phone sees new casts/uploads quickly.
    var photos = await fetchPhotos(tok);
    // Newest first by server timestamp — keep this order in the UI.
    photos = List<CloudGalleryPhoto>.from(photos)
      ..sort((a, b) => b.atMs.compareTo(a.atMs));

    final prefs = await SharedPreferences.getInstance();
    final deleted = prefs.getStringList(_kDeletedIds) ?? const <String>[];
    final deletedSet = deleted.toSet();

    var idToPath = await _loadIdToPath();
    final galleryDir = await GalleryImageCache.galleryDirForSync();
    final orderedLocal = <String>[];
    final nextIdToPath = Map<String, String>.from(idToPath);

    for (final photo in photos) {
      if (deletedSet.contains(photo.id)) {
        nextIdToPath.remove(photo.id);
        continue;
      }
      var local = idToPath[photo.id];
      if (local != null && local.isNotEmpty && await File(local).exists()) {
        orderedLocal.add(local);
        nextIdToPath[photo.id] = local;
        continue;
      }
      local = await _downloadToDir(galleryDir, photo);
      if (local == null) continue;
      nextIdToPath[photo.id] = local;
      orderedLocal.add(local);
    }

    // Always apply cloud order when we have any photos (even if some downloads
    // failed) so newest remote uploads stay at the front.
    if (orderedLocal.isNotEmpty || photos.isNotEmpty) {
      await PersonalGalleryStore.instance.replaceWithCloudPaths(orderedLocal);
      await _saveIdToPath(nextIdToPath);
    }

    if (uploadLocalFirst) {
      await uploadLocalOnly(
        authToken: tok,
        deviceId: deviceId,
        maxUploads: 8,
      );
    }
  }

  /// Ensures [photoIds] exist as local files and are mapped in the cloud id cache.
  /// Returns id → local path for every photo that could be resolved.
  Future<Map<String, String>> ensurePhotosLocal({
    required String authToken,
    required Iterable<String> photoIds,
  }) async {
    final tok = authToken.trim();
    final wanted = photoIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
    if (tok.isEmpty || wanted.isEmpty) return {};

    var idToPath = await _loadIdToPath();
    final out = <String, String>{};
    final missing = <String>[];
    for (final id in wanted) {
      final local = idToPath[id];
      if (local != null && local.isNotEmpty && await File(local).exists()) {
        out[id] = local;
      } else {
        missing.add(id);
      }
    }
    if (missing.isEmpty) return out;

    final photos = await fetchPhotos(tok);
    final byId = <String, CloudGalleryPhoto>{
      for (final p in photos) p.id: p,
    };
    final galleryDir = await GalleryImageCache.galleryDirForSync();
    for (final id in missing) {
      final photo = byId[id];
      if (photo == null || photo.url.isEmpty) continue;
      final local = await _downloadToDir(galleryDir, photo);
      if (local == null) continue;
      idToPath[id] = local;
      out[id] = local;
    }
    await _saveIdToPath(idToPath);
    if (out.isNotEmpty) {
      // Keep gallery list in sync with newly downloaded album members.
      final ordered = <String>[];
      final photosOrdered = await fetchPhotos(tok);
      for (final p in photosOrdered) {
        final path = idToPath[p.id];
        if (path != null && path.isNotEmpty) ordered.add(path);
      }
      // Also keep any newly fetched album-only paths at front if missing from list.
      for (final path in out.values) {
        if (!ordered.contains(path)) ordered.insert(0, path);
      }
      if (ordered.isNotEmpty) {
        await PersonalGalleryStore.instance.replaceWithCloudPaths(ordered);
      }
    }
    return out;
  }

  Future<String?> _downloadToDir(
    Directory galleryDir,
    CloudGalleryPhoto photo,
  ) async {
    try {
      final res = await http
          .get(Uri.parse(photo.url))
          .timeout(_requestTimeout);
      if (res.statusCode < 200 || res.statusCode >= 300) return null;
      final ext = p.extension(Uri.parse(photo.url).path);
      final safeExt =
          ext.isNotEmpty && ext.length <= 5 ? ext : '.jpg';
      final out = File(p.join(galleryDir.path, '${photo.id}$safeExt'));
      await out.writeAsBytes(res.bodyBytes, flush: true);
      return out.path;
    } catch (e) {
      AppDiagLog.verbose('[UserGallery] download ${photo.id} failed: $e');
      return null;
    }
  }

  /// Permanently deletes a gallery photo from the account.
  /// [photoId] is the cloud upload id; [localPath] is used to resolve id from cache.
  Future<bool> deletePhoto({
    required String authToken,
    String? photoId,
    String? localPath,
  }) async {
    final tok = authToken.trim();
    var id = (photoId ?? '').trim();
    final prefs = await SharedPreferences.getInstance();

    if (id.isEmpty && localPath != null && localPath.isNotEmpty) {
      final rawMeta = prefs.getString(_kSyncedIds);
      if (rawMeta != null && rawMeta.isNotEmpty) {
        try {
          final m = jsonDecode(rawMeta) as Map<String, dynamic>;
          for (final e in m.entries) {
            if ('${e.value}' == localPath) {
              id = e.key;
              break;
            }
          }
        } catch (_) {}
      }
    }
    if (id.isEmpty) return false;

    // Tombstone first so a concurrent sync cannot re-add it.
    final deleted = List<String>.from(prefs.getStringList(_kDeletedIds) ?? const []);
    if (!deleted.contains(id)) {
      deleted.insert(0, id);
      await prefs.setStringList(_kDeletedIds, deleted.take(500).toList());
    }

    try {
      final res = await http
          .delete(
            _uri('/api/user/gallery/$id'),
            headers: _authHeaders(tok),
          )
          .timeout(_requestTimeout);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final idToPath = await _loadIdToPath();
        idToPath.remove(id);
        await _saveIdToPath(idToPath);
        return true;
      }
      AppDiagLog.verbose('[UserGallery] delete ${res.statusCode} ${res.body}');
      return false;
    } catch (e, st) {
      AppDiagLog.verbose('[UserGallery] delete failed: $e\n$st');
      return false;
    }
  }
}
