import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import 'permission_gate.dart';

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
      var list = await picker.pickMultiImage();
      // iOS returns [] when user cancels — do not open single-image picker.
      if (list.isEmpty && Platform.isAndroid) {
        final one = await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 4096,
          maxHeight: 4096,
        );
        if (one != null) list = [one];
      }
      return list;
    } finally {
      _open = false;
    }
  }
}
