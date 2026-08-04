import 'dart:convert';
import 'dart:io';

import 'gallery_image_cache.dart';
import 'local_storage_service.dart';

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

  List<SendAlbumEntry> _albums = [];

  /// Local timestamp id → cloud id after [rebindAlbumId].
  final Map<String, String> _idAliases = {};

  List<SendAlbumEntry> get albums => List.unmodifiable(_albums);

  /// Follow rebind aliases so UI that still holds a local id finds the album.
  String resolveAlbumId(String albumId) {
    var cur = albumId.trim();
    if (cur.isEmpty) return cur;
    final seen = <String>{};
    while (_idAliases.containsKey(cur) && seen.add(cur)) {
      cur = _idAliases[cur]!;
    }
    return cur;
  }

  SendAlbumEntry? albumById(String albumId) {
    final id = resolveAlbumId(albumId);
    for (final a in _albums) {
      if (a.id == id) return a;
    }
    return null;
  }

  Future<void> load({String? userId}) async {
    final raw = await LocalStorageService.instance.getString(
      LocalStorageService.sendAlbumsBase,
      userId: userId,
    );
    if (raw == null || raw.isEmpty) {
      _albums = [];
      return;
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      _albums = list
          .map((e) => SendAlbumEntry.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      await _pruneMissingPaths(userId: userId);
    } catch (_) {
      _albums = [];
    }
  }

  Future<void> _pruneMissingPaths({String? userId}) async {
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
      await _persist(userId: userId);
    }
  }

  Future<void> createAlbum(String name, List<String> initialPaths) async {
    await load();
    // Prefer fast stage — picker already durable-copied; avoid JPEG re-encode lag.
    final stored = await GalleryImageCache.persistPaths(
      initialPaths,
      normalizeJpeg: false,
    );
    final id = '${DateTime.now().millisecondsSinceEpoch}';
    _albums.insert(
      0,
      SendAlbumEntry(id: id, name: name.trim().isEmpty ? 'Album' : name.trim(), paths: stored),
    );
    await _persist();
  }

  Future<void> addPathsToAlbum(String albumId, List<String> more) async {
    await load();
    final stored = await GalleryImageCache.persistPaths(
      more,
      normalizeJpeg: false,
    );
    final id = resolveAlbumId(albumId);
    final i = _albums.indexWhere((a) => a.id == id);
    if (i < 0) return;
    final cur = List<String>.from(_albums[i].paths);
    for (final t in stored) {
      if (!cur.contains(t)) cur.add(t);
    }
    _albums[i] = SendAlbumEntry(id: _albums[i].id, name: _albums[i].name, paths: cur);
    await _persist();
  }

  /// Replace membership in-place (used when re-sending an updated playlist).
  /// Returns false if the album id is missing.
  Future<bool> replaceAlbumPaths(String albumId, List<String> paths) async {
    await load();
    final id = resolveAlbumId(albumId);
    final i = _albums.indexWhere((a) => a.id == id);
    if (i < 0) return false;
    final stored = await GalleryImageCache.persistPaths(
      paths,
      normalizeJpeg: false,
    );
    // Dedupe by path so create+send never doubles the same file.
    final unique = <String>[];
    for (final p in stored) {
      final t = p.trim();
      if (t.isEmpty || unique.contains(t)) continue;
      unique.add(t);
    }
    _albums[i] = SendAlbumEntry(
      id: _albums[i].id,
      name: _albums[i].name,
      paths: unique,
    );
    await _persist();
    return true;
  }

  /// Removes paths from the album only (does not delete files or Personal library entries).
  Future<void> removePathsFromAlbum(String albumId, Iterable<String> toRemove) async {
    await load();
    final id = resolveAlbumId(albumId);
    final i = _albums.indexWhere((a) => a.id == id);
    if (i < 0) return;
    final removeSet = toRemove.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
    if (removeSet.isEmpty) return;
    final cur = List<String>.from(_albums[i].paths);
    cur.removeWhere((p) => removeSet.contains(p.trim()));
    _albums[i] = SendAlbumEntry(id: _albums[i].id, name: _albums[i].name, paths: cur);
    await _persist();
  }

  /// Cascade-remove a personal photo path from every local album (account delete).
  Future<int> removePathFromAllAlbums(String path) async {
    await load();
    final target = path.trim();
    if (target.isEmpty) return 0;
    var touched = 0;
    for (var i = 0; i < _albums.length; i++) {
      final cur = List<String>.from(_albums[i].paths);
      final before = cur.length;
      cur.removeWhere((p) => p.trim() == target);
      if (cur.length == before) continue;
      _albums[i] = SendAlbumEntry(
        id: _albums[i].id,
        name: _albums[i].name,
        paths: cur,
      );
      touched++;
    }
    if (touched > 0) await _persist();
    return touched;
  }

  Future<void> deleteAlbum(String albumId) async {
    await load();
    final id = resolveAlbumId(albumId);
    final raw = albumId.trim();
    _albums.removeWhere((a) => a.id == id || a.id == raw);
    await _persist();
    await tombstoneAlbumId(id);
    if (raw.isNotEmpty && raw != id) await tombstoneAlbumId(raw);
    // Also tombstone any alias that pointed at this album.
    final pointing = _idAliases.entries
        .where((e) => e.value == id || e.key == id || e.key == raw)
        .map((e) => e.key)
        .toList();
    for (final k in pointing) {
      await tombstoneAlbumId(k);
      _idAliases.remove(k);
    }
  }

  /// Record an album id that must never be re-imported from cloud sync.
  Future<void> tombstoneAlbumId(String albumId) async {
    final id = albumId.trim();
    if (id.isEmpty) return;
    final deleted = await LocalStorageService.instance.getStringList(
      LocalStorageService.sendAlbumsDeletedBase,
    );
    if (!deleted.contains(id)) {
      deleted.insert(0, id);
      await LocalStorageService.instance.setStringList(
        LocalStorageService.sendAlbumsDeletedBase,
        deleted.take(200).toList(),
      );
    }
  }

  /// IDs of albums deleted from this account — never re-import on sync.
  Future<Set<String>> deletedAlbumIds() async {
    final deleted = await LocalStorageService.instance.getStringList(
      LocalStorageService.sendAlbumsDeletedBase,
    );
    return deleted.toSet();
  }

  Future<void> renameAlbum(String albumId, String newName) async {
    await load();
    final id = resolveAlbumId(albumId);
    final i = _albums.indexWhere((a) => a.id == id);
    if (i < 0) return;
    final n = newName.trim().isEmpty ? 'Album' : newName.trim();
    _albums[i] = SendAlbumEntry(
      id: _albums[i].id,
      name: n,
      paths: List<String>.from(_albums[i].paths),
    );
    await _persist();
  }

  Future<void> _persist({String? userId}) async {
    await LocalStorageService.instance.setString(
      LocalStorageService.sendAlbumsBase,
      jsonEncode(_albums.map((e) => e.toJson()).toList()),
      userId: userId,
    );
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

    final idToPath = <String, String>{};
    try {
      final raw = await LocalStorageService.instance.getString(
        LocalStorageService.galleryCloudIdsBase,
      );
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
      // Only keep prior local membership when cloud resolved nothing yet
      // (avoid duplicating the same photo as local path + downloaded cloud path).
      if (paths.isEmpty && existing != null) {
        for (final p in existing.paths) {
          final t = p.trim();
          if (t.isEmpty || paths.contains(t)) continue;
          if (await _fileExists(t)) paths.add(t);
        }
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
    if (i < 0) {
      // Already rebound or missing — still record alias for stale UI ids.
      _idAliases[from] = to;
      await tombstoneAlbumId(from);
      return;
    }
    final cur = _albums[i];
    // If cloud id already exists as another row, merge paths into it.
    final existingTo = _albums.indexWhere((a) => a.id == to);
    if (existingTo >= 0 && existingTo != i) {
      final dest = _albums[existingTo];
      final merged = List<String>.from(dest.paths);
      for (final p in cur.paths) {
        if (!merged.contains(p)) merged.add(p);
      }
      _albums[existingTo] = SendAlbumEntry(
        id: to,
        name: (name ?? dest.name).trim().isEmpty ? dest.name : (name ?? dest.name),
        paths: merged,
      );
      _albums.removeAt(i);
    } else {
      _albums[i] = SendAlbumEntry(
        id: to,
        name: (name ?? cur.name).trim().isEmpty ? cur.name : (name ?? cur.name),
        paths: List<String>.from(cur.paths),
      );
    }
    _idAliases[from] = to;
    await _persist();
    // Never re-import the ephemeral local id after it has been replaced.
    await tombstoneAlbumId(from);
  }

  void resetMemory() {
    _albums = [];
    _idAliases.clear();
  }

  /// Wipe albums + tombstones for [userId] **before** clearing the JWT.
  Future<void> clearAllForUser(String userId) async {
    final uid = userId.trim();
    if (uid.isEmpty) return;
    await LocalStorageService.instance.remove(
      LocalStorageService.sendAlbumsBase,
      userId: uid,
    );
    await LocalStorageService.instance.remove(
      LocalStorageService.sendAlbumsDeletedBase,
      userId: uid,
    );
    _albums = [];
    _idAliases.clear();
  }

  Future<void> clearAllForAccount() async {
    final uid = await LocalStorageService.instance.currentUserId();
    await clearAllForUser(uid);
  }

  static Future<bool> _fileExists(String path) async {
    try {
      return await File(path).exists();
    } catch (_) {
      return false;
    }
  }
}
