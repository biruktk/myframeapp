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
      atMs: (j['atMs'] as num?)?.toInt() ?? 0,
      deviceId: j['deviceId']?.toString(),
    );
  }
}

/// Syncs the personal gallery with VPS (`GET/POST /api/user/gallery`).
class UserGalleryCloudService {
  UserGalleryCloudService._();
  static final UserGalleryCloudService instance = UserGalleryCloudService._();

  static const _requestTimeout = Duration(seconds: 30);
  static const _kSyncedIds = 'personal_gallery_cloud_ids_v1';
  static const _kDeletedIds = 'personal_gallery_deleted_ids_v1';

  Uri _uri(String path) {
    final base = ApiConfig.baseUrl.replaceAll(RegExp(r'/+$'), '');
    final pth = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$base$pth');
  }

  Map<String, String> _authHeaders(String token) => {
        'Accept': 'application/json',
        'Authorization': 'Bearer ${token.trim()}',
      };

  Future<List<CloudGalleryPhoto>> fetchPhotos(String authToken) async {
    final tok = authToken.trim();
    if (tok.isEmpty) return const [];
    try {
      final res = await http
          .get(_uri('/api/user/gallery'), headers: _authHeaders(tok))
          .timeout(_requestTimeout);
      if (res.statusCode != 200) {
        AppDiagLog.verbose('[UserGallery] fetch ${res.statusCode} ${res.body}');
        return const [];
      }
      final map = jsonDecode(res.body) as Map<String, dynamic>;
      if (map['ok'] == false) return const [];
      final raw = map['photos'];
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

  Future<void> uploadFile({
    required String authToken,
    required String localPath,
    String? deviceId,
  }) async {
    final tok = authToken.trim();
    if (tok.isEmpty) return;
    final file = File(localPath);
    if (!await file.exists()) return;
    try {
      final req = http.MultipartRequest('POST', _uri('/api/user/gallery'))
        ..headers.addAll(_authHeaders(tok))
        ..files.add(await http.MultipartFile.fromPath('file', localPath))
        ..fields.addAll({
          if (deviceId != null && deviceId.trim().isNotEmpty)
            'device_id': deviceId.trim(),
        });
      final streamed = await req.send().timeout(_requestTimeout);
      final body = await streamed.stream.bytesToString();
      if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
        AppDiagLog.verbose('[UserGallery] upload ${streamed.statusCode} $body');
      }
    } catch (e, st) {
      AppDiagLog.verbose('[UserGallery] upload failed: $e\n$st');
    }
  }

  /// Downloads cloud photos and merges into [PersonalGalleryStore] (newest first).
  /// Skips any IDs in the local tombstone list (deleted on this or another client).
  Future<void> syncFromServer(String authToken) async {
    final photos = await fetchPhotos(authToken);
    if (photos.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final deleted = prefs.getStringList(_kDeletedIds) ?? const <String>[];
    final deletedSet = deleted.toSet();

    Map<String, String> idToPath = {};
    final rawMeta = prefs.getString(_kSyncedIds);
    if (rawMeta != null && rawMeta.isNotEmpty) {
      try {
        final m = jsonDecode(rawMeta) as Map<String, dynamic>;
        idToPath = m.map((k, v) => MapEntry(k, '$v'));
      } catch (_) {}
    }

    final galleryDir = await GalleryImageCache.galleryDirForSync();
    final orderedLocal = <String>[];
    final nextIdToPath = <String, String>{};

    for (final photo in photos) {
      if (deletedSet.contains(photo.id)) continue;
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

    if (orderedLocal.isEmpty) return;

    await PersonalGalleryStore.instance.replaceWithCloudPaths(orderedLocal);
    await prefs.setString(_kSyncedIds, jsonEncode(nextIdToPath));
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

    // Drop from local id→path map.
    final rawMeta = prefs.getString(_kSyncedIds);
    if (rawMeta != null && rawMeta.isNotEmpty) {
      try {
        final m = Map<String, dynamic>.from(jsonDecode(rawMeta) as Map);
        m.remove(id);
        await prefs.setString(_kSyncedIds, jsonEncode(m));
      } catch (_) {}
    }

    if (tok.isEmpty) return true;

    try {
      var res = await http
          .delete(
            _uri('/api/v1/user/media/$id'),
            headers: _authHeaders(tok),
          )
          .timeout(_requestTimeout);
      if (res.statusCode == 200 || res.statusCode == 204) return true;
      res = await http
          .delete(
            _uri('/api/user/gallery/$id'),
            headers: _authHeaders(tok),
          )
          .timeout(_requestTimeout);
      return res.statusCode == 200 || res.statusCode == 204;
    } catch (e, st) {
      AppDiagLog.verbose('[UserGallery] delete failed: $e\n$st');
      return false;
    }
  }

  Future<String?> _downloadToDir(Directory dir, CloudGalleryPhoto photo) async {
    try {
      final res = await http.get(Uri.parse(photo.url)).timeout(_requestTimeout);
      if (res.statusCode != 200 || res.bodyBytes.isEmpty) return null;
      var ext = p.extension(Uri.parse(photo.url).path).toLowerCase();
      if (ext.isEmpty || ext.length > 8) ext = '.jpg';
      final dest = File(
        p.join(dir.path, 'cloud_${photo.id}${ext == '.bin' ? '.jpg' : ext}'),
      );
      await dest.writeAsBytes(res.bodyBytes, flush: true);
      return dest.path;
    } catch (e) {
      AppDiagLog.verbose('[UserGallery] download ${photo.url}: $e');
      return null;
    }
  }
}
