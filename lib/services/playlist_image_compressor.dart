import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

Future<Uint8List> compressPlaylistImage(Uint8List bytes) => compute(_compress, bytes);
Uint8List _compress(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) throw StateError('Unsupported playlist image');
  var image = img.bakeOrientation(decoded);
  if (image.width > 1600 || image.height > 1600) {
    image = image.width >= image.height ? img.copyResize(image, width: 1600) : img.copyResize(image, height: 1600);
  }
  for (;;) {
    for (final quality in [85, 75, 65, 55]) {
      final result = Uint8List.fromList(img.encodeJpg(image, quality: quality));
      if (result.length < 500000) return result;
    }
    if (image.width <= 320 || image.height <= 320) throw StateError('Image too large');
    image = img.copyResize(image, width: (image.width * .8).round());
  }
}
