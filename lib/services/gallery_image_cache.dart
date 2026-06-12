import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'app_diag_log.dart';

/// Copies gallery picks out of iOS `/tmp` (image_picker) into app documents.
class GalleryImageCache {
  GalleryImageCache._();

  static const _subdir = 'personal_gallery';

  /// Exposed for cloud gallery downloads (same folder as local picks).
  static Future<Directory> galleryDirForSync() => _dir();

  static Future<Directory> _dir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, _subdir));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static bool _isUnderGalleryDir(String path, String galleryRoot) {
    final normalized = p.normalize(path);
    final root = p.normalize(galleryRoot);
    return normalized == root || normalized.startsWith('$root${Platform.pathSeparator}');
  }

  /// Returns a durable path under app documents. Copies when needed.
  static Future<String?> persistFromPath(String sourcePath) async {
    final src = sourcePath.trim();
    if (src.isEmpty) return null;

    try {
      final galleryDir = await _dir();
      if (_isUnderGalleryDir(src, galleryDir.path)) {
        if (await File(src).exists()) return src;
        return null;
      }

      final file = File(src);
      if (!await file.exists()) return null;

      var ext = p.extension(src).toLowerCase();
      if (ext.isEmpty || ext.length > 8) ext = '.jpg';
      final name =
          '${DateTime.now().millisecondsSinceEpoch}_${src.hashCode.abs()}$ext';
      final dest = File(p.join(galleryDir.path, name));
      await file.copy(dest.path);
      return dest.path;
    } catch (e, st) {
      AppDiagLog.verbose('[GalleryImageCache] persist failed $src: $e\n$st');
      return null;
    }
  }

  static Future<List<String>> persistPaths(Iterable<String> paths) async {
    final out = <String>[];
    for (final path in paths) {
      final stored = await persistFromPath(path);
      if (stored != null) out.add(stored);
    }
    return out;
  }

  static Future<List<String>> filterExisting(Iterable<String> paths) async {
    final out = <String>[];
    for (final path in paths) {
      final t = path.trim();
      if (t.isEmpty) continue;
      try {
        if (await File(t).exists()) out.add(t);
      } catch (_) {}
    }
    return out;
  }
}
