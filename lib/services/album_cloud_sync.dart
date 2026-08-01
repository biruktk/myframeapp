import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import 'app_diag_log.dart';
import 'frame_api_client.dart';
import 'send_albums_store.dart';
import 'user_gallery_cloud_service.dart';
import 'user_playlist_remote_api.dart';

/// Cross-device sync for Gallery albums / playlists.
///
/// Albums are account data (like gallery photos): create/edit/delete should
/// appear on every signed-in phone. Photo membership uses cloud media IDs
/// from [UserGalleryCloudService]; local paths are resolved on each device.
///
/// Deletes sync account/cloud to other phones; the server also notifies
/// frames playing that playlist to stop (see DELETE /api/user/playlists).
class AlbumCloudSync {
  AlbumCloudSync._();
  static final instance = AlbumCloudSync._();

  static const _kSyncedIds = 'personal_gallery_cloud_ids_v1';
  static const _requestTimeout = Duration(seconds: 20);

  Uri _uri(String path) {
    final base = ApiConfig.baseUrl.replaceAll(RegExp(r'/+$'), '');
    final pth = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$base$pth');
  }

  Map<String, String> _authHeaders(String token) => {
        'Accept': 'application/json',
        'Authorization': 'Bearer ${token.trim()}',
        'Content-Type': 'application/json',
      };

  Future<Map<String, String>> _idToPath() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kSyncedIds);
    if (raw == null || raw.isEmpty) return {};
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return m.map((k, v) => MapEntry(k, '$v'));
    } catch (_) {
      return {};
    }
  }

  Future<Map<String, String>> _pathToId() async {
    final idToPath = await _idToPath();
    final out = <String, String>{};
    for (final e in idToPath.entries) {
      out[e.value] = e.key;
      // Also index by basename so remapped cache copies still resolve.
      final base = e.value.split(Platform.pathSeparator).last;
      if (base.isNotEmpty) out.putIfAbsent(base, () => e.key);
    }
    return out;
  }

  /// Push local albums, then pull server albums and merge (names + photo refs).
  Future<void> syncAll(String authToken, {bool pushLocal = true}) async {
    final tok = authToken.trim();
    if (tok.isEmpty) return;
    try {
      if (pushLocal) {
        await UserGalleryCloudService.instance.uploadLocalOnly(
          authToken: tok,
          maxUploads: 12,
        );
        await _pushLocalAlbums(tok);
      }
      await _pullRemoteAlbums(tok);
    } catch (e, st) {
      AppDiagLog.verbose('[AlbumSync] syncAll failed: $e\n$st');
    }
  }

  /// Immediate push after create / add / rename / delete.
  Future<void> pushAlbum(String albumId, String authToken) async {
    final tok = authToken.trim();
    if (tok.isEmpty) return;
    await SendAlbumsStore.instance.load();
    SendAlbumEntry? album;
    for (final a in SendAlbumsStore.instance.albums) {
      if (a.id == albumId) {
        album = a;
        break;
      }
    }
    if (album == null) {
      await FrameApiClient().deleteUserAlbum(bearerToken: tok, albumId: albumId);
      return;
    }
    // Upload album members first so photoIds are available for PATCH.
    for (final path in album.paths) {
      if (!await File(path).exists()) continue;
      await UserGalleryCloudService.instance.uploadFile(
        authToken: tok,
        localPath: path,
      );
    }
    await _upsertAlbum(tok, album);
  }

  Future<void> _pushLocalAlbums(String tok) async {
    await SendAlbumsStore.instance.load();
    for (final album in SendAlbumsStore.instance.albums) {
      await _upsertAlbum(tok, album);
    }
  }

  Future<void> _upsertAlbum(String tok, SendAlbumEntry album) async {
    final pathToId = await _pathToId();
    final photoIds = <String>[];
    for (final path in album.paths) {
      var id = pathToId[path] ??
          pathToId[path.split(Platform.pathSeparator).last];
      if (id == null || id.isEmpty) {
        final uploaded = await UserGalleryCloudService.instance.uploadFile(
          authToken: tok,
          localPath: path,
        );
        if (uploaded != null && uploaded != 'ok') {
          id = uploaded;
          pathToId[path] = id;
        }
      }
      if (id != null && id.isNotEmpty && id != 'ok') {
        photoIds.add(id);
      }
    }

    final api = UserPlaylistRemoteApi(bearerToken: tok);
    final looksLocal =
        RegExp(r'^\d{10,}$').hasMatch(album.id); // millis timestamp ids

    if (looksLocal) {
      final created = await api.createPlaylist(title: album.name);
      if (created == null) {
        AppDiagLog.verbose('[AlbumSync] createPlaylist failed for ${album.name}');
        return;
      }
      await SendAlbumsStore.instance.rebindAlbumId(
        fromId: album.id,
        toId: created.id,
        name: created.title.isNotEmpty ? created.title : album.name,
      );
      if (photoIds.isNotEmpty) {
        final updated = await api.updatePlaylistPhotos(
          playlistId: created.id,
          photoIds: photoIds,
        );
        AppDiagLog.verbose(
          '[AlbumSync] created ${created.id} photos=${photoIds.length} ok=${updated != null}',
        );
      }
      await _putAlbumV1(tok, created.id, album.name, photoIds);
      return;
    }

    final updated = await api.updatePlaylistPhotos(
      playlistId: album.id,
      photoIds: photoIds,
    );
    AppDiagLog.verbose(
      '[AlbumSync] patch ${album.id} photos=${photoIds.length} ok=${updated != null}',
    );
    await _putAlbumV1(tok, album.id, album.name, photoIds);
  }

  Future<void> _putAlbumV1(
    String tok,
    String id,
    String name,
    List<String> photoIds,
  ) async {
    try {
      final res = await http
          .put(
            _uri('/api/v1/user/albums/$id'),
            headers: _authHeaders(tok),
            body: jsonEncode({
              'name': name,
              'title': name,
              'photo_ids': photoIds,
              'photoIds': photoIds,
            }),
          )
          .timeout(_requestTimeout);
      if (res.statusCode >= 200 && res.statusCode < 300) return;
      await http
          .post(
            _uri('/api/v1/user/albums'),
            headers: _authHeaders(tok),
            body: jsonEncode({
              'id': id,
              'name': name,
              'title': name,
              'photo_ids': photoIds,
              'photoIds': photoIds,
            }),
          )
          .timeout(_requestTimeout);
    } catch (_) {}
  }

  Future<void> _pullRemoteAlbums(String tok) async {
    final meta = <Map<String, dynamic>>[];
    final seenIds = <String>{};

    void addMeta(Map<String, dynamic> m) {
      final id = '${m['id'] ?? m['album_id'] ?? ''}'.trim();
      if (id.isEmpty || seenIds.contains(id)) return;
      seenIds.add(id);
      meta.add(m);
    }

    final albums = await FrameApiClient().fetchUserAlbums(bearerToken: tok);
    for (final a in albums) {
      addMeta(Map<String, dynamic>.from(a));
    }

    try {
      final dash =
          await UserPlaylistRemoteApi(bearerToken: tok).fetchDashboard();
      if (dash != null) {
        for (final pl in dash.playlists) {
          addMeta({
            'id': pl.id,
            'name': pl.title,
            'title': pl.title,
            'photo_ids': pl.photoIds,
            'photoIds': pl.photoIds,
          });
        }
      }
    } catch (_) {}

    if (meta.isEmpty) {
      AppDiagLog.verbose('[AlbumSync] pull: no remote albums — drop synced ones');
      await SendAlbumsStore.instance.applyPlaylistsMeta(const []);
      return;
    }

    // Collect every photo id referenced by albums and force-download them.
    final allPhotoIds = <String>[];
    for (final m in meta) {
      final rawIds = m['photo_ids'] ?? m['photoIds'] ?? m['media_ids'];
      if (rawIds is! List) continue;
      for (final raw in rawIds) {
        final pid = '$raw'.trim();
        if (pid.isNotEmpty) allPhotoIds.add(pid);
      }
    }
    AppDiagLog.verbose(
      '[AlbumSync] pull albums=${meta.length} photoIds=${allPhotoIds.length}',
    );

    final idToPath = await UserGalleryCloudService.instance.ensurePhotosLocal(
      authToken: tok,
      photoIds: allPhotoIds,
    );

    await SendAlbumsStore.instance.applyPlaylistsMeta(
      meta,
      cloudIdToPath: idToPath,
    );

    // Log unresolved so we can see empty-album cases in verbose logs.
    for (final m in meta) {
      final id = '${m['id'] ?? ''}'.trim();
      final rawIds = m['photo_ids'] ?? m['photoIds'];
      if (rawIds is! List) continue;
      var resolved = 0;
      for (final raw in rawIds) {
        final pid = '$raw'.trim();
        final path = idToPath[pid];
        if (path != null && path.isNotEmpty) resolved++;
      }
      AppDiagLog.verbose(
        '[AlbumSync] album $id resolved $resolved/${rawIds.length} photos',
      );
    }
  }
}
