import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import 'gallery_image_cache.dart';
import 'local_storage_service.dart';

/// Local paths added from the Gallery tab (personal library only; no social graph).
class PersonalGalleryStore {
  PersonalGalleryStore._();
  static final instance = PersonalGalleryStore._();

  List<String> _paths = [];

  /// Bumped when paths change so [GalleryScreen] can refresh while kept alive.
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  List<String> get paths => List.unmodifiable(_paths);

  Future<void> load({String? userId}) async {
    final raw = await LocalStorageService.instance.getString(
      LocalStorageService.galleryPathsBase,
      userId: userId,
    );
    if (raw == null || raw.isEmpty) {
      _paths = [];
      return;
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final loaded = list.map((e) => '$e').where((e) => e.isNotEmpty).toList();
      _paths = await GalleryImageCache.filterExisting(loaded);
      if (_paths.length != loaded.length) await _persist(userId: userId);
    } catch (_) {
      _paths = [];
    }
  }

  Future<void> addPaths(List<String> paths) async {
    await load();
    // Already staged by the picker — skip JPEG re-encode and full-library SHA256.
    final stored = await GalleryImageCache.persistPaths(
      paths,
      normalizeJpeg: false,
    );
    for (final t in stored) {
      if (!_paths.contains(t)) _paths.insert(0, t);
    }
    if (_paths.length > 200) _paths = _paths.sublist(0, 200);
    await _persist();
    revision.value++;
  }

  Future<void> removeAt(int index) async {
    await load();
    if (index < 0 || index >= _paths.length) return;
    _paths.removeAt(index);
    await _persist();
    revision.value++;
  }

  /// Drops paths that vanished from account cloud (deleted on another phone).
  Future<void> removePaths(Iterable<String> paths) async {
    await load();
    final drop = paths.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
    if (drop.isEmpty) return;
    final before = _paths.length;
    _paths = _paths.where((p) => !drop.contains(p)).toList();
    if (_paths.length == before) return;
    await _persist();
    revision.value++;
  }

  /// Clears in-memory list only (after logout JWT is already gone).
  void resetMemory() {
    _paths = [];
    revision.value++;
  }

  /// Wipe prefs for a specific account **before** clearing the JWT.
  Future<void> clearForUser(String userId) async {
    final uid = userId.trim();
    if (uid.isEmpty) return;
    await LocalStorageService.instance.remove(
      LocalStorageService.galleryPathsBase,
      userId: uid,
    );
    _paths = [];
    revision.value++;
  }

  Future<void> clear() async {
    _paths = [];
    await _persist();
    revision.value++;
  }

  /// Applies cloud gallery order (newest first) as the authority.
  /// Local-only files that are not content-duplicates stay after the cloud set.
  Future<void> replaceWithCloudPaths(List<String> cloudPaths) async {
    await load();
    final cloudOrdered = <String>[];
    final cloudSeenHash = <String>{};
    for (final path in cloudPaths) {
      if (path.isEmpty || cloudOrdered.contains(path)) continue;
      final h = await _hashFile(path);
      if (h != null) {
        if (!cloudSeenHash.add(h)) continue;
      }
      cloudOrdered.add(path);
    }

    final localOnly = <String>[];
    for (final p in _paths) {
      if (cloudOrdered.contains(p)) continue;
      final h = await _hashFile(p);
      if (h != null && cloudSeenHash.contains(h)) continue;
      if (!localOnly.contains(p)) localOnly.add(p);
    }

    _paths = [...cloudOrdered, ...localOnly];
    if (_paths.length > 200) _paths = _paths.sublist(0, 200);
    await _persist();
    revision.value++;
  }

  static Future<String?> _hashFile(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      return sha256.convert(bytes).toString();
    } catch (_) {
      return null;
    }
  }

  Future<void> _persist({String? userId}) async {
    await LocalStorageService.instance.setString(
      LocalStorageService.galleryPathsBase,
      jsonEncode(_paths),
      userId: userId,
    );
  }
}
