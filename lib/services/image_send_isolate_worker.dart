import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../models/send_overlay_options.dart';
import 'image_processor_service.dart';
import 'send_overlay_paint.dart';

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
    this.flipH = false,
    this.flipV = false,
    this.cropAspect = 0,
    this.cropZoom = 1.0,
    this.cropPanX = 0,
    this.cropPanY = 0,
  });

  final Uint8List imageBytes;
  final int quarterTurns;
  final double brightness;
  final double contrast;
  final double saturation;
  final int filterIndex;
  final SendOverlayOptions overlay;
  final String locationText;
  final bool flipH;
  final bool flipV;
  final double cropAspect;
  final double cropZoom;
  final double cropPanX;
  final double cropPanY;
}

FrameImageFilter _filterEnumAt(int index) {
  final vals = FrameImageFilter.values;
  final last = vals.length - 1;
  final i = index < 0 ? 0 : index > last ? last : index;
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
  bool flipH = false,
  bool flipV = false,
  double cropAspect = 0,
  double cropZoom = 1.0,
  double cropPanX = 0,
  double cropPanY = 0,
}) {
  final decoded = proc.decode(imageBytes);
  if (decoded == null) return null;

  var work = proc.buildFrameWorkImage(
    source: decoded,
    quarterTurns: quarterTurns,
    flipH: flipH,
    flipV: flipV,
    cropAspect: cropAspect,
    cropZoom: cropZoom,
    cropPanX: cropPanX,
    cropPanY: cropPanY,
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

Uint8List? isolateFastPreviewJpeg(FrameProcessOnlyArgs args) {
  final filter = _filterEnumAt(args.filterIndex);
  final proc = ImageProcessorService();
  final decoded = proc.decode(args.imageBytes);
  if (decoded == null) return null;

  var work = proc.buildFrameWorkImage(
    source: decoded,
    quarterTurns: args.quarterTurns,
    flipH: args.flipH,
    flipV: args.flipV,
    cropAspect: args.cropAspect,
    cropZoom: args.cropZoom,
    cropPanX: args.cropPanX,
    cropPanY: args.cropPanY,
    brightness: args.brightness,
    contrast: args.contrast,
    saturation: args.saturation,
    filter: filter,
  );
  if (work == null) return null;
  if (args.overlay.hasAnyOverlay) {
    work = drawSendOverlayOnImage(work, args.overlay, locationText: args.locationText);
  }
  return proc.encodeJpg(work, quality: 85);
}

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
    this.flipH = false,
    this.flipV = false,
    this.cropAspect = 0,
    this.cropZoom = 1.0,
    this.cropPanX = 0,
    this.cropPanY = 0,
  });

  final Uint8List imageBytes;
  final int quarterTurns;
  final double brightness;
  final double contrast;
  final double saturation;
  final int filterIndex;
  final SendOverlayOptions overlay;
  final String locationText;
  final bool flipH;
  final bool flipV;
  final double cropAspect;
  final double cropZoom;
  final double cropPanX;
  final double cropPanY;
}

Uint8List? isolateComposeCloudJpeg(ComposeUploadIsolateArgs args) {
  final filter = _filterEnumAt(args.filterIndex);
  final proc = ImageProcessorService();
  final decoded = proc.decode(args.imageBytes);
  if (decoded == null) return null;

  var work = proc.buildCloudCopyImage(
    source: decoded,
    quarterTurns: args.quarterTurns,
    flipH: args.flipH,
    flipV: args.flipV,
    cropAspect: args.cropAspect,
    cropZoom: args.cropZoom,
    cropPanX: args.cropPanX,
    cropPanY: args.cropPanY,
    brightness: args.brightness,
    contrast: args.contrast,
    saturation: args.saturation,
    filter: filter,
  );
  if (work == null) return null;
  if (args.overlay.hasAnyOverlay) {
    work = drawSendOverlayOnImage(work, args.overlay, locationText: args.locationText);
  }
  return proc.encodeJpg(work, quality: 100);
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
    flipH: args.flipH,
    flipV: args.flipV,
    cropAspect: args.cropAspect,
    cropZoom: args.cropZoom,
    cropPanX: args.cropPanX,
    cropPanY: args.cropPanY,
  );
  if (work == null) return null;
  return proc.processWorkImageForFrame(work);
}

Uint8List? isolateFrameEinkPreviewJpeg(FrameProcessOnlyArgs args) {
  return isolateFrameProcessOnly(args)?.einkPreviewJpeg;
}
