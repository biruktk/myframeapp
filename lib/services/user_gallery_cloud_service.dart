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
  Future<void> syncFromServer(String authToken) async {
    final photos = await fetchPhotos(authToken);
    if (photos.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
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

    for (final photo in photos) {
      var local = idToPath[photo.id];
      if (local != null && local.isNotEmpty && await File(local).exists()) {
        orderedLocal.add(local);
        continue;
      }
      local = await _downloadToDir(galleryDir, photo);
      if (local == null) continue;
      idToPath[photo.id] = local;
      orderedLocal.add(local);
    }

    if (orderedLocal.isEmpty) return;

    await PersonalGalleryStore.instance.replaceWithCloudPaths(orderedLocal);
    await prefs.setString(_kSyncedIds, jsonEncode(idToPath));
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
