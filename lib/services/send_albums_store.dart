import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import 'gallery_image_cache.dart';

/// Named albums used from the Send flow (paths on device).
class SendAlbumEntry {
  SendAlbumEntry({required this.id, required this.name, required this.paths});

  final String id;
  final String name;
  final List<String> paths;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'paths': paths};

  static SendAlbumEntry fromJson(Map<String, dynamic> j) => SendAlbumEntry(
        id: '${j['id'] ?? ''}',
        name: '${j['name'] ?? 'Album'}',
        paths: List<String>.from((j['paths'] as List?) ?? const []),
      );
}

class SendAlbumsStore {
  SendAlbumsStore._();
  static final SendAlbumsStore instance = SendAlbumsStore._();

  static const _k = 'send_albums_v1';
  static const _kAuthUserId = 'settings_auth_user_id';

  static Future<String> _scopedKey() async {
    final p = await SharedPreferences.getInstance();
    final uid = p.getString(_kAuthUserId) ?? 'guest';
    return '${_k}_$uid';
  }

  List<SendAlbumEntry> _albums = [];

  List<SendAlbumEntry> get albums => List.unmodifiable(_albums);

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final key = await _scopedKey();
    final raw = p.getString(key);
    if (raw == null || raw.isEmpty) {
      _albums = [];
      return;
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      _albums = list.map((e) => SendAlbumEntry.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      await _pruneMissingPaths();
    } catch (_) {
      _albums = [];
    }
  }

  Future<void> _pruneMissingPaths() async {
    var changed = false;
    final next = <SendAlbumEntry>[];
    for (final a in _albums) {
      final kept = await GalleryImageCache.filterExisting(a.paths);
      if (kept.length != a.paths.length) changed = true;
      if (kept.isNotEmpty) {
        next.add(SendAlbumEntry(id: a.id, name: a.name, paths: kept));
      } else if (a.paths.isEmpty) {
        next.add(a);
      } else {
        changed = true;
      }
    }
    if (changed) {
      _albums = next;
      await _persist();
    }
  }

  Future<void> createAlbum(String name, List<String> initialPaths) async {
    await load();
    final stored = await GalleryImageCache.persistPaths(initialPaths);
    final id = '${DateTime.now().millisecondsSinceEpoch}';
    _albums.insert(
      0,
      SendAlbumEntry(id: id, name: name.trim().isEmpty ? 'Album' : name.trim(), paths: stored),
    );
    await _persist();
  }

  Future<void> addPathsToAlbum(String albumId, List<String> more) async {
    await load();
    final stored = await GalleryImageCache.persistPaths(more);
    final i = _albums.indexWhere((a) => a.id == albumId);
    if (i < 0) return;
    final cur = List<String>.from(_albums[i].paths);
    for (final t in stored) {
      if (!cur.contains(t)) cur.add(t);
    }
    _albums[i] = SendAlbumEntry(id: _albums[i].id, name: _albums[i].name, paths: cur);
    await _persist();
  }

  /// Removes paths from the album only (does not delete files or Personal library entries).
  Future<void> removePathsFromAlbum(String albumId, Iterable<String> toRemove) async {
    await load();
    final i = _albums.indexWhere((a) => a.id == albumId);
    if (i < 0) return;
    final removeSet = toRemove.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
    if (removeSet.isEmpty) return;
    final cur = List<String>.from(_albums[i].paths);
    cur.removeWhere((p) => removeSet.contains(p.trim()));
    _albums[i] = SendAlbumEntry(id: _albums[i].id, name: _albums[i].name, paths: cur);
    await _persist();
  }

  Future<void> deleteAlbum(String albumId) async {
    await load();
    final id = albumId.trim();
    _albums.removeWhere((a) => a.id == id);
    await _persist();
    // Tombstone so a later cloud sync cannot re-import this album.
    if (id.isNotEmpty) {
      final p = await SharedPreferences.getInstance();
      final key = 'send_albums_deleted_ids_v1';
      final deleted = List<String>.from(p.getStringList(key) ?? const []);
      if (!deleted.contains(id)) {
        deleted.insert(0, id);
        await p.setStringList(key, deleted.take(200).toList());
      }
    }
  }

  /// IDs of albums deleted from this account — never re-import on sync.
  Future<Set<String>> deletedAlbumIds() async {
    final p = await SharedPreferences.getInstance();
    return (p.getStringList('send_albums_deleted_ids_v1') ?? const []).toSet();
  }

  Future<void> renameAlbum(String albumId, String newName) async {
    await load();
    final i = _albums.indexWhere((a) => a.id == albumId);
    if (i < 0) return;
    final n = newName.trim().isEmpty ? 'Album' : newName.trim();
    _albums[i] = SendAlbumEntry(
      id: _albums[i].id,
      name: n,
      paths: List<String>.from(_albums[i].paths),
    );
    await _persist();
  }

  Future<void> _persist() async {
    final p = await SharedPreferences.getInstance();
    final key = await _scopedKey();
    await p.setString(key, jsonEncode(_albums.map((e) => e.toJson()).toList()));
  }

  /// Apply cloud playlist / album metadata.
  ///
  /// When [cloudIdToPath] is provided, `photo_ids` / `photoIds` are resolved to
  /// local gallery paths so albums show the same photos on every device.
  Future<void> applyPlaylistsMeta(
    List<Map<String, dynamic>> meta, {
    Map<String, String>? cloudIdToPath,
  }) async {
    await load();
    final deleted = await deletedAlbumIds();
    final byId = {for (final a in _albums) a.id: a};
    final next = <SendAlbumEntry>[];
    final seen = <String>{};

    // Merge caller map with persisted gallery id→path cache.
    final idToPath = <String, String>{};
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('personal_gallery_cloud_ids_v1');
      if (raw != null && raw.isNotEmpty) {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        for (final e in m.entries) {
          idToPath[e.key] = '${e.value}';
        }
      }
    } catch (_) {}
    if (cloudIdToPath != null) idToPath.addAll(cloudIdToPath);

    for (final m in meta) {
      final id = '${m['id'] ?? m['album_id'] ?? ''}'.trim();
      if (id.isEmpty || deleted.contains(id)) continue;
      seen.add(id);
      final name = '${m['name'] ?? m['title'] ?? 'Album'}'.trim();
      final existing = byId[id];
      final paths = <String>[];
      final rawIds = m['photo_ids'] ?? m['photoIds'] ?? m['media_ids'];
      if (rawIds is List) {
        for (final raw in rawIds) {
          final pid = '$raw'.trim();
          if (pid.isEmpty) continue;
          final path = idToPath[pid];
          if (path != null &&
              path.isNotEmpty &&
              !paths.contains(path) &&
              await _fileExists(path)) {
            paths.add(path);
          }
        }
      }
      // If server has photo ids but none resolved yet, keep prior local paths
      // only when the album already had content (avoid wiping during race).
      if (paths.isEmpty && existing != null && existing.paths.isNotEmpty) {
        paths.addAll(existing.paths);
      }
      next.add(
        SendAlbumEntry(
          id: id,
          name: name.isEmpty ? 'Album' : name,
          paths: paths,
        ),
      );
    }

    for (final a in _albums) {
      if (seen.contains(a.id) || deleted.contains(a.id)) continue;
      // Keep only not-yet-pushed local albums (timestamp ids). Cloud albums
      // missing from the server list were deleted on another device — drop them.
      // Server delete also notifies frames to stop that playlist.
      final looksLocal = RegExp(r'^\d{10,}$').hasMatch(a.id);
      if (looksLocal) next.add(a);
    }

    _albums = next;
    await _persist();
  }

  /// Replace a local-only album id with the cloud id after createPlaylist.
  Future<void> rebindAlbumId({
    required String fromId,
    required String toId,
    String? name,
  }) async {
    await load();
    final from = fromId.trim();
    final to = toId.trim();
    if (from.isEmpty || to.isEmpty || from == to) return;
    final i = _albums.indexWhere((a) => a.id == from);
    if (i < 0) return;
    final cur = _albums[i];
    _albums[i] = SendAlbumEntry(
      id: to,
      name: (name ?? cur.name).trim().isEmpty ? cur.name : (name ?? cur.name),
      paths: List<String>.from(cur.paths),
    );
    await _persist();
  }

  Future<void> clearAllForAccount() async {
    await load();
    _albums = [];
    await _persist();
    final p = await SharedPreferences.getInstance();
    await p.remove('send_albums_deleted_ids_v1');
  }

  static Future<bool> _fileExists(String path) async {
    try {
      return await File(path).exists();
    } catch (_) {
      return false;
    }
  }
}
