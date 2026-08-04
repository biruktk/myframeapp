import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../l10n/app_strings.dart';
import 'gallery_image_cache.dart';
import 'permission_gate.dart';

const int kMaxMultiPick = 10;

/// Shared gallery multi-pick; avoids reopening picker on iOS cancel.
///
/// Returns durable paths under app documents via a **fast file copy** (no
/// serial JPEG re-encode). Album grids can paint immediately; upload paths
/// normalize later as needed.
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
          final s = AppStrings.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              content: Text(s.maxImagesAtATime),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }

      if (list.isEmpty) return const [];

      // Fast durable copies only — JPEG re-encode used to block UI for ~30s.
      final staged = await GalleryImageCache.stageQuickCopies(
        list.map((x) => x.path),
      );

      if (staged.isEmpty && context.mounted) {
        final s = AppStrings.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(s.decodeError),
          ),
        );
        return const [];
      }

      if (staged.length < list.length && context.mounted) {
        final skipped = list.length - staged.length;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Skipped $skipped photo(s) that could not be saved.'),
          ),
        );
      }

      return staged
          .map((path) => XFile(path, mimeType: 'image/jpeg'))
          .toList(growable: false);
    } finally {
      _open = false;
    }
  }
}
