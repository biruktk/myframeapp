import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

/// Gallery multi-pick used by slideshow / playlist flows.
class SlideshowPhotoPicker {
  SlideshowPhotoPicker._();

  static Future<List<XFile>> pickMulti(BuildContext context) async {
    if (Platform.isAndroid || Platform.isIOS) {
      var next = await Permission.photos.status;
      if (!next.isGranted && !next.isLimited) {
        next = await Permission.photos.request();
      }
      if (!next.isGranted && !next.isLimited) return [];
    }
    final picker = ImagePicker();
    var list = await picker.pickMultiImage();
    if (list.isEmpty) {
      final one = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 4096,
        maxHeight: 4096,
      );
      if (one != null) list = [one];
    }
    return list;
  }
}
