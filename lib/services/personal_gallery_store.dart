import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Local paths added from the Gallery tab (personal library only; no social graph).
class PersonalGalleryStore {
  PersonalGalleryStore._();
  static final PersonalGalleryStore instance = PersonalGalleryStore._();

  static const _kPaths = 'personal_gallery_file_paths_v1';
  List<String> _paths = [];

  List<String> get paths => List.unmodifiable(_paths);

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kPaths);
    if (raw == null || raw.isEmpty) {
      _paths = [];
      return;
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      _paths = list.map((e) => '$e').where((e) => e.isNotEmpty).toList();
    } catch (_) {
      _paths = [];
    }
  }

  Future<void> addPaths(List<String> paths) async {
    await load();
    for (final x in paths) {
      final t = x.trim();
      if (t.isEmpty) continue;
      if (!_paths.contains(t)) _paths.insert(0, t);
    }
    if (_paths.length > 200) _paths = _paths.sublist(0, 200);
    await _persist();
  }

  Future<void> removeAt(int index) async {
    await load();
    if (index < 0 || index >= _paths.length) return;
    _paths.removeAt(index);
    await _persist();
  }

  Future<void> clear() async {
    _paths = [];
    await _persist();
  }

  Future<void> _persist() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kPaths, jsonEncode(_paths));
  }
}
