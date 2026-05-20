import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../models/send_overlay_options.dart';
import 'image_processor_service.dart';
import 'send_overlay_paint.dart';

/// Passed to [compute] from the editor — must not depend on Flutter BuildContext.
class ComposeUploadIsolateArgs {
  ComposeUploadIsolateArgs({
    required this.imageBytes,
    required this.quarterTurns,
    required this.brightness,
    required this.contrast,
    required this.saturation,
    required this.filterIndex,
    required this.overlay,
    required this.locationText,
  });

  final Uint8List imageBytes;
  final int quarterTurns;
  final double brightness;
  final double contrast;
  final double saturation;
  final int filterIndex;
  final SendOverlayOptions overlay;
  final String locationText;
}

/// SD export / cached process — no JPEG re-encode + overlay pass.
class FrameProcessOnlyArgs {
  FrameProcessOnlyArgs({
    required this.imageBytes,
    required this.quarterTurns,
    required this.brightness,
    required this.contrast,
    required this.saturation,
    required this.filterIndex,
  });

  final Uint8List imageBytes;
  final int quarterTurns;
  final double brightness;
  final double contrast;
  final double saturation;
  final int filterIndex;
}

FrameImageFilter _filterEnumAt(int index) {
  final vals = FrameImageFilter.values;
  final last = vals.length - 1;
  final i =
      index < 0 ? 0 : index > last ? last : index; // avoids num vs [] trailing-comma quirks
  return vals[i];
}

ProcessedFrameResult? isolateFrameProcessOnly(FrameProcessOnlyArgs args) {
  final filter = _filterEnumAt(args.filterIndex);
  final proc = ImageProcessorService();
  final decoded = proc.decode(args.imageBytes);
  if (decoded == null) return null;
  return proc.processForFrame(
    source: decoded,
    quarterTurns: args.quarterTurns,
    brightness: args.brightness,
    contrast: args.contrast,
    saturation: args.saturation,
    filter: filter,
  );
}

Uint8List? isolateComposeUploadJpeg(ComposeUploadIsolateArgs args) {
  final filter = _filterEnumAt(args.filterIndex);

  final proc = ImageProcessorService();
  final decoded = proc.decode(args.imageBytes);
  if (decoded == null) return null;

  final graded = proc.processForFrame(
    source: decoded,
    quarterTurns: args.quarterTurns,
    brightness: args.brightness,
    contrast: args.contrast,
    saturation: args.saturation,
    filter: filter,
  );
  if (graded == null) return null;

  final frameRgb = img.decodeImage(graded.frameJpeg);
  if (frameRgb == null) return null;

  final overlaid =
      drawSendOverlayOnImage(frameRgb, args.overlay, locationText: args.locationText);

  // Do not re-run Floyd–Steinberg dither after drawing text — it destroys overlays.
  return Uint8List.fromList(img.encodeJpg(overlaid, quality: 95));
}
