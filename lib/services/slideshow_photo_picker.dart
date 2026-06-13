import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'gallery_photo_picker.dart';

/// Gallery multi-pick used by slideshow / playlist flows.
class SlideshowPhotoPicker {
  SlideshowPhotoPicker._();

  static Future<List<XFile>> pickMulti(BuildContext context) =>
      GalleryPhotoPicker.pickMulti(context);
}
