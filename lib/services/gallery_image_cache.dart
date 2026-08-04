import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import 'app_diag_log.dart';
import 'file_storage_manager.dart';
import 'gallery_image_normalizer.dart';

/// Copies gallery picks out of iOS `/tmp` (image_picker) into the **active
/// user's** documents folder (`users/<userId>/images/`).
///
/// Prefer [stageQuickCopies] for UI-critical paths (album grid). Full JPEG
/// normalization can run later / only when needed for upload.
class GalleryImageCache {
  GalleryImageCache._();

  /// Exposed for cloud gallery downloads (same folder as local picks).
  static Future<Directory> galleryDirForSync() =>
      FileStorageManager.instance.imagesDir();

  static Future<Directory> _dir() => FileStorageManager.instance.imagesDir();

  static bool _isUnderGalleryDir(String path, String galleryRoot) =>
      FileStorageManager.instance.isUnderDir(path, galleryRoot);

  /// Peek only the JPEG SOI marker — never read the whole file.
  static Future<bool> _isJpegFile(String path) async {
    try {
      final raf = await File(path).open();
      try {
        final header = await raf.read(3);
        return GalleryImageNormalizer.isJpegMagic(Uint8List.fromList(header));
      } finally {
        await raf.close();
      }
    } catch (_) {
      return false;
    }
  }

  /// Fast durable copy (no re-encode). Keeps original bytes/extension.
  /// Use this so album thumbnails can paint immediately after pick.
  static Future<String?> stageQuickCopy(String sourcePath) async {
    final src = sourcePath.trim();
    if (src.isEmpty) return null;
    try {
      final file = File(src);
      if (!await file.exists()) return null;

      final galleryDir = await _dir();
      if (_isUnderGalleryDir(src, galleryDir.path)) {
        return src;
      }

      final ext = p.extension(src).toLowerCase();
      final safeExt = (ext.length >= 2 && ext.length <= 5) ? ext : '.jpg';
      final name =
          '${DateTime.now().millisecondsSinceEpoch}_${src.hashCode.abs()}$safeExt';
      final dest = File(p.join(galleryDir.path, name));
      await file.copy(dest.path);
      return dest.path;
    } catch (e, st) {
      AppDiagLog.verbose('[GalleryImageCache] stageQuickCopy failed $src: $e\n$st');
      return null;
    }
  }

  /// Parallel quick-stage for multi-pick (orders preserved; failed items omitted).
  static Future<List<String>> stageQuickCopies(Iterable<String> paths) async {
    final list = paths.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (list.isEmpty) return const [];
    final results = await Future.wait(list.map(stageQuickCopy));
    return results.whereType<String>().toList();
  }

  /// Returns a durable path under the active user's images dir.
  ///
  /// Already-staged gallery files that are JPEG are returned as-is (header peek).
  /// Non-JPEG gallery files and outside paths are normalized when [normalizeJpeg]
  /// is true; otherwise a quick copy is used.
  static Future<String?> persistFromPath(
    String sourcePath, {
    bool normalizeJpeg = true,
  }) async {
    final src = sourcePath.trim();
    if (src.isEmpty) return null;

    try {
      final galleryDir = await _dir();
      if (_isUnderGalleryDir(src, galleryDir.path)) {
        if (!await File(src).exists()) return null;
        if (await _isJpegFile(src)) return src;
        if (!normalizeJpeg) return src;
        return GalleryImageNormalizer.persistAsJpeg(src);
      }

      if (!normalizeJpeg) {
        return stageQuickCopy(src);
      }
      return GalleryImageNormalizer.persistAsJpeg(src);
    } catch (e, st) {
      AppDiagLog.verbose('[GalleryImageCache] persist failed $src: $e\n$st');
      return null;
    }
  }

  static Future<List<String>> persistPaths(
    Iterable<String> paths, {
    bool normalizeJpeg = true,
  }) async {
    final out = <String>[];
    for (final path in paths) {
      final stored = await persistFromPath(path, normalizeJpeg: normalizeJpeg);
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

  /// Optional: relative name helper for diagnostics.
  static String basename(String path) => p.basename(path);
}
