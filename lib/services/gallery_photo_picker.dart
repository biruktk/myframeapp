import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../l10n/app_strings.dart';
import 'gallery_image_normalizer.dart';
import 'permission_gate.dart';

const int kMaxMultiPick = 10;

/// Shared gallery multi-pick; avoids reopening picker on iOS cancel.
///
/// Every returned [XFile] is a durable **JPEG** under app documents (HEIC / P3
/// screenshots are normalized before the editor or upload sees them).
class GalleryPhotoPicker {
  GalleryPhotoPicker._();

  static var _open = false;

  static Future<List<XFile>> pickMulti(BuildContext context) async {
    if (_open) return [];
    _open = true;
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        final next = await PermissionGate.photos();
        if (!next.isGranted && !next.isLimited) return [];
      }
      final picker = ImagePicker();
      var list = await picker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1080,
        requestFullMetadata: false,
      );
      // iOS returns [] when user cancels — do not open single-image picker.
      if (list.isEmpty && Platform.isAndroid) {
        final one = await picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 85,
          maxWidth: 1920,
          maxHeight: 1080,
          requestFullMetadata: false,
        );
        if (one != null) list = [one];
      }
      if (list.length > kMaxMultiPick) {
        list = list.sublist(0, kMaxMultiPick);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              behavior: SnackBarBehavior.floating,
              content: Text('Max 10 images can be selected at a time.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }

      final normalized = <XFile>[];
      for (final x in list) {
        final jpegPath = await GalleryImageNormalizer.persistAsJpeg(x.path);
        if (jpegPath != null) {
          normalized.add(XFile(jpegPath, mimeType: 'image/jpeg'));
        }
      }

      if (list.isNotEmpty && normalized.isEmpty && context.mounted) {
        final s = AppStrings.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(s.decodeError),
          ),
        );
      } else if (list.isNotEmpty &&
          normalized.length < list.length &&
          context.mounted) {
        final skipped = list.length - normalized.length;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(
              'Skipped $skipped photo(s) that could not be converted to JPEG.',
            ),
          ),
        );
      }

      return normalized;
    } finally {
      _open = false;
    }
  }
}
