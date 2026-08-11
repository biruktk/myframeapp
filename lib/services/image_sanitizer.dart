import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'gallery_image_normalizer.dart';
import 'app_diag_log.dart';

/// Universal image sanitizer/transcoder.
///
/// Every picked image (XFile / File path) should go through [sanitize] before
/// being handed to the canvas, cropper, or upload pipeline. It guarantees a
/// standard 8-bit sRGB JPEG:
///  * on iOS it first asks the native [sanitizeImageToJPEG] channel handler to
///    re-encode via UIKit (this color-manages Display P3 → sRGB and strips the
///    alpha channel, so Flutter's `instantiateImageCodec` never chokes on
///    screenshot PNGs / HEIC / 16-bit PNGs);
///  * the pure-Dart [GalleryImageNormalizer] is the cross-platform fallback;
///  * already-standard 8-bit sRGB JPEGs pass through unchanged (no re-encode).
class ImageSanitizer {
  ImageSanitizer._();

  static const MethodChannel _channel = MethodChannel('myframe/native_ble/methods');

  /// Sanitizes the picked image at [filePath] and returns the path of a
  /// standard sRGB JPEG (a temp `.jpg` in the app cache), or the original path
  /// when it is already a plain JPEG. Returns `null` when the file is missing
  /// or cannot be decoded.
  static Future<String?> sanitize(String filePath) async {
    final path = filePath.trim();
    if (path.isEmpty) return null;

    final file = File(path);
    if (!await file.exists()) return null;

    // Fast path: already a plain 8-bit sRGB JPEG — no re-encode needed.
    try {
      final raw = await file.readAsBytes();
      if (GalleryImageNormalizer.detectKind(raw) == ImageKind.jpeg &&
          !GalleryImageNormalizer.hasEmbeddedProfile(raw)) {
        return path;
      }
    } catch (_) {
      return null;
    }

    // Native iOS transcoding (Display P3 / HEIC / 16-bit PNG / alpha).
    if (Platform.isIOS) {
      try {
        final String? sanitizedPath = await _channel.invokeMethod<String>(
          'sanitizeImageToJPEG',
          {'filePath': path},
        );
        if (sanitizedPath != null && sanitizedPath.isNotEmpty) {
          final tempFile = File(sanitizedPath);
          if (await tempFile.exists() && await tempFile.length() > 0) {
            return sanitizedPath;
          }
        }
      } catch (e) {
        AppDiagLog.verbose('[ImageSanitizer] native iOS transcoding failed: $e');
      }
    }

    // Fallback: pure-Dart / flutter_image_compress re-encode.
    try {
      final bytes = await file.readAsBytes();
      final jpegBytes = await GalleryImageNormalizer.toJpegBytes(
        bytes,
        pathHint: path,
      );
      if (jpegBytes != null && jpegBytes.isNotEmpty) {
        final cacheDir = await getTemporaryDirectory();
        final destPath =
            '${cacheDir.path}/sanitized_${DateTime.now().millisecondsSinceEpoch}_${path.hashCode.abs()}.jpg';
        final destFile = File(destPath);
        await destFile.writeAsBytes(jpegBytes, flush: true);
        if (await destFile.exists() && await destFile.length() > 0) {
          return destFile.path;
        }
      }
    } catch (e) {
      AppDiagLog.verbose('[ImageSanitizer] fallback transcoding failed: $e');
    }

    return null;
  }
}
