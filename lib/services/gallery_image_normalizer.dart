import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import 'app_diag_log.dart';
import 'file_storage_manager.dart';

/// Detected container of the raw bytes.
enum ImageKind { empty, jpeg, png, heic, other }

/// Parsed PNG IHDR essentials used to decide whether re-encoding is needed.
/// `bitDepth` from IHDR byte 24, `colorType` from byte 25.
typedef PngInfo = ({int bitDepth, int colorType});

/// Converts gallery / camera / share picks to standard sRGB JPEG before the
/// editor, preview, or upload.
///
/// Problem inputs on iOS — HEIC, 16-bit PNG, Display P3 profiled images, and
/// images with an alpha channel — are re-encoded to a plain **8-bit sRGB JPEG**
/// so the frame's decoder never chokes:
///  * native `flutter_image_compress` applies the OS color management
///    (Display P3 → sRGB) and strips alpha because JPEG has no alpha;
///  * the `image` package is the pure-Dart fallback: 16-bit → 8-bit, RGBA →
///    RGB, embedded color profile dropped.
///
/// Already-standard 8-bit sRGB JPEGs pass through unchanged (no quality loss).
class GalleryImageNormalizer {
  GalleryImageNormalizer._();

  static const int _maxSide = 1920;
  static const int _quality = 88;

  static bool isJpegMagic(Uint8List bytes) =>
      bytes.length > 2 && bytes[0] == 0xff && bytes[1] == 0xd8;

  static bool _isPngMagic(Uint8List b) =>
      b.length >= 8 &&
      b[0] == 0x89 &&
      b[1] == 0x50 &&
      b[2] == 0x4e &&
      b[3] == 0x47;

  static bool _isHeicMagic(Uint8List b) =>
      b.length >= 12 &&
      b[4] == 0x66 && // f
      b[5] == 0x74 && // t
      b[6] == 0x79 && // y
      b[7] == 0x70 && // p
      b[8] == 0x68 && // h
      b[9] == 0x65 && // e
      b[10] == 0x69 && // i
      b[11] == 0x63; // c

  static ImageKind detectKind(Uint8List raw) {
    if (raw.isEmpty) return ImageKind.empty;
    if (isJpegMagic(raw)) return ImageKind.jpeg;
    if (_isPngMagic(raw)) return ImageKind.png;
    if (_isHeicMagic(raw)) return ImageKind.heic;
    return ImageKind.other;
  }

  static PngInfo? pngInfo(Uint8List raw) {
    if (!_isPngMagic(raw) || raw.length < 26) return null;
    return (bitDepth: raw[24], colorType: raw[25]);
  }

  /// PNG color type 4 (grey+alpha) / 6 (RGBA), or indexed (3) with a tRNS chunk.
  static bool pngHasAlpha(Uint8List raw) {
    final info = pngInfo(raw);
    if (info == null) return false;
    if (info.colorType == 4 || info.colorType == 6) return true;
    if (info.colorType == 3) return _pngHasChunk(raw, 'tRNS');
    return false;
  }

  /// 16-bit PNG (ProRAW / some iOS screenshot pipelines produce these).
  static bool pngIs16Bit(Uint8List raw) => (pngInfo(raw)?.bitDepth ?? 8) == 16;

  /// Whether the container embeds an ICC / color profile such as Display P3.
  /// The `image` package cannot color-manage, so profiled files are re-encoded
  /// to a plain sRGB JPEG (native compress applies the OS color management).
  static bool hasEmbeddedProfile(Uint8List raw) {
    final kind = detectKind(raw);
    if (kind == ImageKind.jpeg) return _jpegHasIccProfile(raw);
    if (kind == ImageKind.png) return _pngHasChunk(raw, 'iCCP');
    return false;
  }

  /// `true` when the bytes are not already a standard 8-bit sRGB image and
  /// must be re-encoded before upload / preview.
  static bool needsReencode(Uint8List raw) {
    final kind = detectKind(raw);
    return switch (kind) {
      ImageKind.empty => false,
      ImageKind.jpeg => hasEmbeddedProfile(raw),
      ImageKind.png =>
        pngIs16Bit(raw) || pngHasAlpha(raw) || hasEmbeddedProfile(raw),
      ImageKind.heic || ImageKind.other => true,
    };
  }

  static bool _pngHasChunk(Uint8List raw, String wantedType) {
    var offset = 8; // after the 8-byte PNG signature
    while (offset + 8 <= raw.length) {
      final len =
          (raw[offset] << 24) |
          (raw[offset + 1] << 16) |
          (raw[offset + 2] << 8) |
          raw[offset + 3];
      final type = String.fromCharCodes(raw.sublist(offset + 4, offset + 8));
      if (type == wantedType) return true;
      if (type == 'IEND') break;
      offset += 12 + len;
    }
    return false;
  }

  static bool _jpegHasIccProfile(Uint8List raw) {
    if (raw.length < 4 || raw[0] != 0xff || raw[1] != 0xd8) return false;
    var i = 2;
    while (i + 4 <= raw.length) {
      if (raw[i] != 0xff) {
        i++;
        continue;
      }
      final marker = raw[i + 1];
      final standalone =
          marker == 0xd8 ||
          marker == 0xd9 ||
          marker == 0x01 ||
          (marker >= 0xd0 && marker <= 0xd7);
      if (standalone) {
        i++;
        continue;
      }
      if (marker == 0xda) break; // SOS → entropy-coded data, no more segments
      final len = (raw[i + 2] << 8) | raw[i + 3];
      if (len < 2) break;
      if (marker == 0xe2 && i + 14 <= raw.length) {
        final tag = String.fromCharCodes(raw.sublist(i + 4, i + 14));
        if (tag == 'ICC_PROFILE') return true;
      }
      i += 2 + len;
    }
    return false;
  }

  /// Returns JPEG bytes, or null if the file is empty / undecodable.
  ///
  /// Plain 8-bit sRGB JPEGs are returned unchanged; everything else is
  /// re-encoded via the native codec (HEIC / Display P3 / alpha) with a
  /// pure-Dart fallback.
  static Future<Uint8List?> toJpegBytes(
    Uint8List raw, {
    String? pathHint,
  }) async {
    if (raw.isEmpty) {
      AppDiagLog.verbose('[Normalize] empty bytes path=$pathHint');
      return null;
    }

    // Fast path: already a standard JPEG, no embedded color profile — keep it.
    if (detectKind(raw) == ImageKind.jpeg && !hasEmbeddedProfile(raw)) {
      return raw;
    }

    // Prefer the native codec. On iOS this also handles HEIC and applies the
    // OS color management (Display P3 → sRGB); alpha is dropped (JPEG).
    Uint8List? out;
    final hint = (pathHint ?? '').trim();
    if (hint.isNotEmpty) {
      out = await _compressPath(hint);
    }
    if (out == null || out.isEmpty) {
      out = await _compressList(raw);
    }
    if (out != null && out.isNotEmpty) {
      return Uint8List.fromList(out);
    }

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
      return persistJpegBytes(jpeg, hint: src);
    } catch (e, st) {
      AppDiagLog.verbose('[Normalize] persistAsJpeg failed $src: $e\n$st');
      return null;
    }
  }

  /// Persists already-normalized JPEG bytes under the active user's images dir.
  /// Returns the durable `.jpg` path, or null on failure.
  static Future<String?> persistJpegBytes(
    Uint8List jpegBytes, {
    String? hint,
  }) async {
    if (jpegBytes.isEmpty) return null;
    try {
      final dir = await FileStorageManager.instance.imagesDir();
      final tag = (hint ?? '').trim().isNotEmpty
          ? '_${(hint ?? 'img').hashCode.abs()}'
          : '';
      final name = '${DateTime.now().millisecondsSinceEpoch}$tag.jpg';
      final dest = File(p.join(dir.path, name));
      await dest.writeAsBytes(jpegBytes, flush: true);
      return dest.path;
    } catch (e, st) {
      AppDiagLog.verbose('[Normalize] persistJpegBytes failed: $e\n$st');
      return null;
    }
  }

  /// Normalizes one file for upload. Returns the JPEG-safe [bytes] to send plus
  /// the durable [path] to record (reuses the source path when it is already a
  /// plain 8-bit sRGB JPEG; otherwise writes a normalized `.jpg` under app
  /// documents). Returns null when the file is missing / undecodable.
  static Future<({Uint8List bytes, String path})?> normalizeFileForUpload(
    String sourcePath,
  ) async {
    final src = sourcePath.trim();
    if (src.isEmpty) return null;
    try {
      final file = File(src);
      if (!await file.exists()) return null;
      final raw = await file.readAsBytes();
      if (raw.isEmpty) return null;
      final bytes = await toJpegBytes(raw, pathHint: src);
      if (bytes == null || bytes.isEmpty) return null;
      if (detectKind(raw) == ImageKind.jpeg && !hasEmbeddedProfile(raw)) {
        return (bytes: bytes, path: src);
      }
      final path = await persistJpegBytes(bytes, hint: src);
      if (path == null) return null;
      return (bytes: bytes, path: path);
    } catch (e, st) {
      AppDiagLog.verbose(
        '[Normalize] normalizeFileForUpload failed $src: $e\n$st',
      );
      return null;
    }
  }

  /// Best-effort repair for a preview that failed to render: re-encodes the
  /// source into a plain sRGB JPEG under app documents and returns the new
  /// path (or null). Callers swap the old file for the returned path.
  static Future<String?> repairPathForPreview(String sourcePath) =>
      persistAsJpeg(sourcePath);

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
      // 16-bit PNG/other → 8-bit; RGBA → RGB (alpha stripped); the `image`
      // package cannot color-manage, so drop the embedded profile and treat
      // the (already native-compressed, when applicable) pixels as sRGB.
      final work = decoded.convert(format: img.Format.uint8, numChannels: 3)
        ..iccProfile = null;
      if (work.width == 0 || work.height == 0) return null;
      var out = work;
      if (out.width > _maxSide || out.height > _maxSide) {
        if (out.width >= out.height) {
          out = img.copyResize(
            out,
            width: _maxSide,
            interpolation: img.Interpolation.linear,
          );
        } else {
          out = img.copyResize(
            out,
            height: _maxSide,
            interpolation: img.Interpolation.linear,
          );
        }
      }
      return Uint8List.fromList(img.encodeJpg(out, quality: _quality));
    } catch (e) {
      AppDiagLog.verbose('[Normalize] image package encode failed: $e');
      return null;
    }
  }
}
