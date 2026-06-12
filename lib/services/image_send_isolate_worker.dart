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

/// Preview / SD export — grade, filter, optional caption overlay.
class FrameProcessOnlyArgs {
  FrameProcessOnlyArgs({
    required this.imageBytes,
    required this.quarterTurns,
    required this.brightness,
    required this.contrast,
    required this.saturation,
    required this.filterIndex,
    this.overlay = const SendOverlayOptions(),
    this.locationText = '',
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

FrameImageFilter _filterEnumAt(int index) {
  final vals = FrameImageFilter.values;
  final last = vals.length - 1;
  final i =
      index < 0 ? 0 : index > last ? last : index; // avoids num vs [] trailing-comma quirks
  return vals[i];
}

img.Image? _buildSizedWorkImage({
  required ImageProcessorService proc,
  required Uint8List imageBytes,
  required int quarterTurns,
  required double brightness,
  required double contrast,
  required double saturation,
  required FrameImageFilter filter,
  SendOverlayOptions overlay = const SendOverlayOptions(),
  String locationText = '',
}) {
  final decoded = proc.decode(imageBytes);
  if (decoded == null) return null;

  var work = proc.buildFrameWorkImage(
    source: decoded,
    quarterTurns: quarterTurns,
    brightness: brightness,
    contrast: contrast,
    saturation: saturation,
    filter: filter,
  );
  if (work == null) return null;

  if (overlay.hasAnyOverlay) {
    work = drawSendOverlayOnImage(work, overlay, locationText: locationText);
  }
  return work;
}

ProcessedFrameResult? isolateFrameProcessOnly(FrameProcessOnlyArgs args) {
  final filter = _filterEnumAt(args.filterIndex);
  final proc = ImageProcessorService();
  final work = _buildSizedWorkImage(
    proc: proc,
    imageBytes: args.imageBytes,
    quarterTurns: args.quarterTurns,
    brightness: args.brightness,
    contrast: args.contrast,
    saturation: args.saturation,
    filter: filter,
    overlay: args.overlay,
    locationText: args.locationText,
  );
  if (work == null) return null;
  return proc.processWorkImageForFrame(work);
}

/// Editor preview — 6‑color dither preview (same pipeline as frame `.bin`).
Uint8List? isolateFrameEinkPreviewJpeg(FrameProcessOnlyArgs args) {
  return isolateFrameProcessOnly(args)?.einkPreviewJpeg;
}

/// Wi‑Fi upload: firmware `.bin` (exact E6 palette — screenshots & photos).
Uint8List? isolateComposeUploadBin(ComposeUploadIsolateArgs args) {
  final filter = _filterEnumAt(args.filterIndex);
  final proc = ImageProcessorService();
  final work = _buildSizedWorkImage(
    proc: proc,
    imageBytes: args.imageBytes,
    quarterTurns: args.quarterTurns,
    brightness: args.brightness,
    contrast: args.contrast,
    saturation: args.saturation,
    filter: filter,
    overlay: args.overlay,
    locationText: args.locationText,
  );
  if (work == null) return null;

  final graded = proc.processWorkImageForFrame(work);
  return graded?.binPayload;
}

/// Legacy JPEG upload (VPS MYFM re-encode) — photos only fallback.
Uint8List? isolateComposeUploadFrameJpeg(ComposeUploadIsolateArgs args) {
  final filter = _filterEnumAt(args.filterIndex);
  final proc = ImageProcessorService();
  final work = _buildSizedWorkImage(
    proc: proc,
    imageBytes: args.imageBytes,
    quarterTurns: args.quarterTurns,
    brightness: args.brightness,
    contrast: args.contrast,
    saturation: args.saturation,
    filter: filter,
    overlay: args.overlay,
    locationText: args.locationText,
  );
  if (work == null) return null;

  final graded = proc.processWorkImageForFrame(work);
  return graded?.frameJpeg;
}
