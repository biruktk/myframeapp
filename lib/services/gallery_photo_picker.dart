import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import 'permission_gate.dart';

const int kMaxMultiPick = 10;

/// Shared gallery multi-pick; avoids reopening picker on iOS cancel.
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
      );
      // iOS returns [] when user cancels — do not open single-image picker.
      if (list.isEmpty && Platform.isAndroid) {
        final one = await picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 85,
          maxWidth: 1920,
          maxHeight: 1080,
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
      return list;
    } finally {
      _open = false;
    }
  }
}
