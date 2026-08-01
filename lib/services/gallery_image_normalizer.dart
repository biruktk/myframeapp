import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app_diag_log.dart';

/// Converts gallery / camera / share picks to standard sRGB JPEG before the editor
/// or upload. Native compress handles iOS HEIC; the `image` package is the fallback.
class GalleryImageNormalizer {
  GalleryImageNormalizer._();

  static const int _maxSide = 1920;
  static const int _quality = 88;

  static bool isJpegMagic(Uint8List bytes) =>
      bytes.length > 2 && bytes[0] == 0xff && bytes[1] == 0xd8;

  /// Returns JPEG bytes, or null if the file is empty / undecodable.
  static Future<Uint8List?> toJpegBytes(
    Uint8List raw, {
    String? pathHint,
  }) async {
    if (raw.isEmpty) {
      AppDiagLog.verbose('[Normalize] empty bytes path=$pathHint');
      return null;
    }

    // Prefer path-based native decode on iOS (HEIC / Display P3 screenshots).
    if (pathHint != null && pathHint.trim().isNotEmpty) {
      final fromPath = await _compressPath(pathHint.trim());
      if (fromPath != null) return fromPath;
    }

    final fromList = await _compressList(raw);
    if (fromList != null) return fromList;

    return _encodeWithImagePackage(raw);
  }

  /// Reads [sourcePath], normalizes to JPEG, writes under app documents.
  /// Returns the durable `.jpg` path, or null on failure.
  static Future<String?> persistAsJpeg(String sourcePath) async {
    final src = sourcePath.trim();
    if (src.isEmpty) return null;
    try {
      final file = File(src);
      if (!await file.exists()) return null;
      final raw = await file.readAsBytes();
      if (raw.isEmpty) {
        AppDiagLog.verbose('[Normalize] empty file $src');
        return null;
      }
      final jpeg = await toJpegBytes(raw, pathHint: src);
      if (jpeg == null || jpeg.isEmpty) return null;

      final base = await getApplicationDocumentsDirectory();
      final dir = Directory(p.join(base.path, 'personal_gallery'));
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final name =
          '${DateTime.now().millisecondsSinceEpoch}_${src.hashCode.abs()}.jpg';
      final dest = File(p.join(dir.path, name));
      await dest.writeAsBytes(jpeg, flush: true);
      return dest.path;
    } catch (e, st) {
      AppDiagLog.verbose('[Normalize] persistAsJpeg failed $src: $e\n$st');
      return null;
    }
  }

  static Future<List<String>> persistPathsAsJpeg(Iterable<String> paths) async {
    final out = <String>[];
    for (final path in paths) {
      final stored = await persistAsJpeg(path);
      if (stored != null) out.add(stored);
    }
    return out;
  }

  static Future<Uint8List?> _compressPath(String path) async {
    try {
      final out = await FlutterImageCompress.compressWithFile(
        path,
        minWidth: _maxSide,
        minHeight: _maxSide,
        quality: _quality,
        format: CompressFormat.jpeg,
        keepExif: false,
      );
      if (out == null || out.isEmpty) return null;
      return Uint8List.fromList(out);
    } catch (e) {
      AppDiagLog.verbose('[Normalize] compressWithFile failed: $e');
      return null;
    }
  }

  static Future<Uint8List?> _compressList(Uint8List raw) async {
    try {
      final out = await FlutterImageCompress.compressWithList(
        raw,
        minWidth: _maxSide,
        minHeight: _maxSide,
        quality: _quality,
        format: CompressFormat.jpeg,
        keepExif: false,
      );
      if (out.isEmpty) return null;
      return Uint8List.fromList(out);
    } catch (e) {
      AppDiagLog.verbose('[Normalize] compressWithList failed: $e');
      return null;
    }
  }

  static Uint8List? _encodeWithImagePackage(Uint8List raw) {
    try {
      final decoded = img.decodeImage(raw);
      if (decoded == null) return null;
      // decodeImage applies EXIF orientation; re-encode as plain JPEG (no EXIF).
      var work = decoded;
      if (work.width > _maxSide || work.height > _maxSide) {
        if (work.width >= work.height) {
          work = img.copyResize(
            work,
            width: _maxSide,
            interpolation: img.Interpolation.linear,
          );
        } else {
          work = img.copyResize(
            work,
            height: _maxSide,
            interpolation: img.Interpolation.linear,
          );
        }
      }
      return Uint8List.fromList(img.encodeJpg(work, quality: _quality));
    } catch (e) {
      AppDiagLog.verbose('[Normalize] image package encode failed: $e');
      return null;
    }
  }
}
