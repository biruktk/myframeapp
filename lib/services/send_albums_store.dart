import 'dart:convert';

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
  List<SendAlbumEntry> _albums = [];

  List<SendAlbumEntry> get albums => List.unmodifiable(_albums);

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_k);
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
      next.add(SendAlbumEntry(id: a.id, name: a.name, paths: kept));
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
    await p.setString(_k, jsonEncode(_albums.map((e) => e.toJson()).toList()));
  }
}
