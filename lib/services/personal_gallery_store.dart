import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'gallery_image_cache.dart';

/// Local paths added from the Gallery tab (personal library only; no social graph).
class PersonalGalleryStore {
  PersonalGalleryStore._();
  static final instance = PersonalGalleryStore._();

  static const _kPaths = 'personal_gallery_file_paths_v1';
  static const _kAuthUserId = 'settings_auth_user_id';

  static Future<String> _scopedKey() async {
    final p = await SharedPreferences.getInstance();
    final uid = p.getString(_kAuthUserId) ?? 'guest';
    return '${_kPaths}_$uid';
  }

  List<String> _paths = [];

  /// Bumped when paths change so [GalleryScreen] can refresh while kept alive.
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  List<String> get paths => List.unmodifiable(_paths);

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final key = await _scopedKey();
    final raw = p.getString(key);
    if (raw == null || raw.isEmpty) {
      _paths = [];
      return;
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final loaded = list.map((e) => '$e').where((e) => e.isNotEmpty).toList();
      _paths = await GalleryImageCache.filterExisting(loaded);
      if (_paths.length != loaded.length) await _persist();
    } catch (_) {
      _paths = [];
    }
  }

  Future<void> addPaths(List<String> paths) async {
    await load();
    final stored = await GalleryImageCache.persistPaths(paths);
    for (final t in stored) {
      if (!_paths.contains(t)) _paths.insert(0, t);
    }
    _paths = await _dedupeByContentHashKeepOrder(_paths);
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

    // Cloud chronological order first — never let local-only shuffle it.
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

  static Future<List<String>> _dedupeByContentHashKeepOrder(
    List<String> paths,
  ) async {
    final seen = <String>{};
    final out = <String>[];
    for (final path in paths) {
      final h = await _hashFile(path);
      if (h == null) {
        if (!out.contains(path)) out.add(path);
        continue;
      }
      if (seen.add(h)) out.add(path);
    }
    return out;
  }

  Future<void> _persist() async {
    final p = await SharedPreferences.getInstance();
    final key = await _scopedKey();
    await p.setString(key, jsonEncode(_paths));
  }
}
