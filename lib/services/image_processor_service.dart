import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Pipeline for XT ePaper 13.3″ E6: crop → rotate → user grade → **1200×1600** preprocess
/// (contrast 1.3, sharpness 1.5) → **Floyd–Steinberg** → 6‑color palette → 13.3E6 `.bin`.
///
/// `.bin`: 4‑byte BE `1200`, `1600`; pixel data left half (columns 0–599) then right half,
/// row-major, 4bpp packed (high nibble first). Indices 0,1,2,3,5,6 only (4 unused).
/// Matches confirmed working firmware behavior.
///
/// Resize uses [img.Interpolation.cubic] — the `image` package has no Lanczos; cubic is its
/// highest‑quality scaler.
class ImageProcessorService {
  static const int frameWidth = 1200;
  static const int frameHeight = 1600;
  static const int _halfW = frameWidth ~/ 2;
  static const int _nibblesPerHalf = _halfW * frameHeight;
  static const int _packedHalfLen = _nibblesPerHalf ~/ 2;
  static const int _xtBinTotalBytes = 4 + _packedHalfLen * 2;

  /// Fixed XT pre‑quantize steps (spec), applied after resize to frame size.
  static const double _xtContrastFactor = 1.28;
  static const double _xtSharpnessFactor = 1.45;

  /// E6 color panel needs boosted saturation before server MYFM / Floyd–Steinberg.
  static const double _xtSaturationFactor = 1.58;
  static const double _xtBrightnessFactor = 1.04;

  static const List<int> _xtSearchOrder = [0, 1, 2, 3, 5, 6];

  static const double _fs7 = 7.0 / 16.0;
  static const double _fs3 = 3.0 / 16.0;
  static const double _fs5 = 5.0 / 16.0;
  static const double _fs1 = 1.0 / 16.0;

  static img.ColorRgb8 _xtPaletteColor(int idx) {
    switch (idx) {
      case 0:
        return img.ColorRgb8(0, 0, 0);
      case 1:
        return img.ColorRgb8(255, 255, 255);
      case 2:
        return img.ColorRgb8(255, 255, 0);
      case 3:
        return img.ColorRgb8(255, 0, 0);
      case 5:
        return img.ColorRgb8(0, 0, 255);
      case 6:
        return img.ColorRgb8(0, 255, 0);
      default:
        return img.ColorRgb8(0, 0, 0);
    }
  }

  img.Image? decode(Uint8List bytes) {
    final im = img.decodeImage(bytes);
    if (im == null) return null;
    return _flattenAlpha(im);
  }

  /// PNG / HEIC picks often carry alpha; transparent pixels decode as black and
  /// dither to an all-black MYFM frame without this flatten step.
  img.Image _flattenAlpha(img.Image src) {
    if (!src.hasAlpha) return src;
    final flat = img.Image(width: src.width, height: src.height);
    img.fill(flat, color: img.ColorRgb8(255, 255, 255));
    img.compositeImage(flat, src);
    return flat;
  }

  Uint8List encodeJpg(img.Image image, {int quality = 95}) =>
      Uint8List.fromList(img.encodeJpg(image, quality: quality));

  /// Quick preview (max side) for editor UI.
  img.Image buildPreview({
    required img.Image source,
    int quarterTurns = 0,
    double brightness = 1.0,
    double contrast = 1.0,
    double saturation = 1.0,
    FrameImageFilter filter = FrameImageFilter.none,
    int maxSide = 520,
  }) {
    var work = _applyRotation(source, quarterTurns);
    work = _centerCropAspect(work, frameWidth / frameHeight);
    final m = math.max(work.width, work.height).toDouble();
    final scale = maxSide / m;
    final nw = math.max(1, (work.width * scale).round());
    final nh = math.max(1, (work.height * scale).round());
    work = img.copyResize(
      work,
      width: nw,
      height: nh,
      interpolation: img.Interpolation.linear,
    );
    work = _applyColorGrade(
      work,
      brightness: brightness,
      contrast: contrast,
      saturation: saturation,
    );
    work = _applyNamedFilter(work, filter);
    return work;
  }

  /// Rotate, optional flip, aspect crop + zoom/pan, resize to frame, grade, filter.
  img.Image? buildFrameWorkImage({
    required img.Image source,
    int quarterTurns = 0,
    bool flipH = false,
    bool flipV = false,
    /// Width/height ratio for the crop window. `<= 0` means frame 3:4.
    double cropAspect = 0,
    double cropZoom = 1.0,
    double cropPanX = 0,
    double cropPanY = 0,
    double brightness = 1.0,
    double contrast = 1.0,
    double saturation = 1.0,
    FrameImageFilter filter = FrameImageFilter.none,
  }) {
    try {
      var work = _applyRotation(source, quarterTurns);
      if (flipH) work = img.flipHorizontal(work);
      if (flipV) work = img.flipVertical(work);

      final frameAspect = frameWidth / frameHeight;
      final windowAspect = cropAspect > 0 ? cropAspect : frameAspect;
      work = _cropWithZoomPan(
        work,
        windowAspect,
        cropZoom.clamp(1.0, 3.0),
        cropPanX.clamp(-1.0, 1.0),
        cropPanY.clamp(-1.0, 1.0),
      );
      work = _fitIntoFrame(work, frameAspect);

      work = img.copyResize(
        work,
        width: frameWidth,
        height: frameHeight,
        interpolation: img.Interpolation.cubic,
      );
      work = _liftVeryDark(work);
      work = _applyColorGrade(
        work,
        brightness: brightness,
        contrast: contrast,
        saturation: saturation,
      );
      return _applyNamedFilter(work, filter);
    } catch (_) {
      return null;
    }
  }

  /// High-quality full-color copy for user cloud libraries. This keeps the same
  /// crop/edit intent as the frame send, but skips the e-paper color boosting,
  /// sharpening, palette conversion, and binary encoding steps.
  img.Image? buildCloudCopyImage({
    required img.Image source,
    int quarterTurns = 0,
    bool flipH = false,
    bool flipV = false,
    double cropAspect = 0,
    double cropZoom = 1.0,
    double cropPanX = 0,
    double cropPanY = 0,
    double brightness = 1.0,
    double contrast = 1.0,
    double saturation = 1.0,
    FrameImageFilter filter = FrameImageFilter.none,
  }) {
    try {
      var work = _applyRotation(source, quarterTurns);
      if (flipH) work = img.flipHorizontal(work);
      if (flipV) work = img.flipVertical(work);

      final frameAspect = frameWidth / frameHeight;
      final windowAspect = cropAspect > 0 ? cropAspect : frameAspect;
      work = _cropWithZoomPan(
        work,
        windowAspect,
        cropZoom.clamp(1.0, 3.0),
        cropPanX.clamp(-1.0, 1.0),
        cropPanY.clamp(-1.0, 1.0),
      );
      work = _fitIntoFrame(work, frameAspect);

      work = img.copyResize(
        work,
        width: frameWidth,
        height: frameHeight,
        interpolation: img.Interpolation.cubic,
      );
      work = _applyColorGrade(
        work,
        brightness: brightness,
        contrast: contrast,
        saturation: saturation,
      );
      return _applyNamedFilter(work, filter);
    } catch (_) {
      return null;
    }
  }

  /// Full pipeline for frame + binary XT `.bin` payload (no encryption).
  ProcessedFrameResult? processForFrame({
    required img.Image source,
    int quarterTurns = 0,
    double brightness = 1.0,
    double contrast = 1.0,
    double saturation = 1.0,
    FrameImageFilter filter = FrameImageFilter.none,
  }) {
    final work = buildFrameWorkImage(
      source: source,
      quarterTurns: quarterTurns,
      brightness: brightness,
      contrast: contrast,
      saturation: saturation,
      filter: filter,
    );
    if (work == null) return null;
    return processWorkImageForFrame(work);
  }

  /// Screenshots, logos, and UI captures — preserve flat colors (no heavy grade).
  static bool looksLikeFlatGraphic(img.Image work) {
    var sumL = 0.0;
    var sumC = 0.0;
    var samples = 0;
    final frame = work.frames.first;
    const step = 10;
    for (var y = 0; y < work.height; y += step) {
      for (var x = 0; x < work.width; x += step) {
        final p = frame.getPixel(x, y);
        final r = p.r.toDouble();
        final g = p.g.toDouble();
        final b = p.b.toDouble();
        sumL += 0.299 * r + 0.587 * g + 0.114 * b;
        final maxC = math.max(r, math.max(g, b));
        final minC = math.min(r, math.min(g, b));
        sumC += maxC - minC;
        samples++;
      }
    }
    if (samples == 0) return false;
    final avgL = sumL / samples;
    final avgC = sumC / samples;
    return avgL > 128 && avgC < 62;
  }

  /// XT preprocess → Floyd–Steinberg → `.bin` from an already-sized work image.
  ProcessedFrameResult? processWorkImageForFrame(img.Image work) {
    try {
      if (work.width != frameWidth || work.height != frameHeight) {
        throw StateError('work image must be ${frameWidth}x$frameHeight');
      }

      final graphic = looksLikeFlatGraphic(work);

      // Photos: boost saturation/contrast for E6. Graphics: minimal touch.
      final xtPrep = img.adjustColor(
        work,
        brightness: graphic ? 1.0 : _xtBrightnessFactor,
        saturation: graphic ? 1.0 : _xtSaturationFactor,
        contrast: graphic ? 1.02 : _xtContrastFactor,
      );
      final xtSharp = graphic
          ? xtPrep
          : _unsharpSharpen(xtPrep, _xtSharpnessFactor);

      final eink = _floydSteinbergToIndexed(xtSharp);
      final bin = _buildXt13e6Bin(eink);

      assert(bin.bytes.length == _xtBinTotalBytes);
      assert(
        bin.bytes[0] == 0x04 &&
            bin.bytes[1] == 0xB0 &&
            bin.bytes[2] == 0x06 &&
            bin.bytes[3] == 0x40,
      );

      return ProcessedFrameResult(
        frameJpeg: encodeJpg(xtSharp, quality: 95),
        einkPreviewJpeg: encodeJpg(eink.preview, quality: 92),
        binPayload: bin.bytes,
        crc32: 0,
      );
    } catch (_) {
      return null;
    }
  }

  /// Lift crushed shadows so dark PNG / night photos do not dither to solid black.
  img.Image _liftVeryDark(img.Image image) {
    var sum = 0.0;
    var samples = 0;
    final frame = image.frames.first;
    const step = 12;
    for (var y = 0; y < image.height; y += step) {
      for (var x = 0; x < image.width; x += step) {
        final p = frame.getPixel(x, y);
        sum += 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
        samples++;
      }
    }
    if (samples == 0) return image;
    final avg = sum / samples;
    if (avg >= 42) return image;
    final lift = (1.0 + (42 - avg) / 70).clamp(1.0, 1.55);
    return img.adjustColor(image, brightness: lift);
  }

  /// Unsharp mask: `factor` > 1 adds high‑frequency emphasis (approx. “sharpness × factor”).
  img.Image _unsharpSharpen(img.Image src, double factor) {
    if ((factor - 1.0).abs() < 1e-6) return src;
    final blurred = img.gaussianBlur(img.Image.from(src), radius: 1);
    final out = img.Image.from(src);
    final amount = factor - 1.0;
    for (final frame in src.frames) {
      for (var y = 0; y < frame.height; y++) {
        for (var x = 0; x < frame.width; x++) {
          final p = frame.getPixel(x, y);
          final bp = blurred.frames[frame.frameIndex].getPixel(x, y);
          final rr = (p.r + (p.r - bp.r) * amount).round().clamp(0, 255);
          final gg = (p.g + (p.g - bp.g) * amount).round().clamp(0, 255);
          final bb = (p.b + (p.b - bp.b) * amount).round().clamp(0, 255);
          out.frames[frame.frameIndex].setPixelRgb(x, y, rr, gg, bb);
        }
      }
    }
    return out;
  }

  img.Image _applyRotation(img.Image image, int quarterTurns) {
    final q = quarterTurns % 4;
    if (q == 0) return image;
    return img.copyRotate(image, angle: q * 90.0);
  }

  /// Crop to [aspect] (w/h), then zoom in and pan within that window.
  img.Image _cropWithZoomPan(
    img.Image image,
    double aspect,
    double zoom,
    double panX,
    double panY,
  ) {
    final base = _centerCropAspect(image, aspect);
    if (zoom <= 1.001 && panX.abs() < 0.001 && panY.abs() < 0.001) {
      return base;
    }
    final w = base.width;
    final h = base.height;
    final cropW = (w / zoom).round().clamp(1, w);
    final cropH = (h / zoom).round().clamp(1, h);
    final maxX = w - cropW;
    final maxY = h - cropH;
    final x = ((maxX / 2) + panX * (maxX / 2)).round().clamp(0, maxX);
    final y = ((maxY / 2) + panY * (maxY / 2)).round().clamp(0, maxY);
    return img.copyCrop(base, x: x, y: y, width: cropW, height: cropH);
  }

  /// Letterbox [image] into the frame aspect with a white background.
  img.Image _fitIntoFrame(img.Image image, double frameAspect) {
    final imgAspect = image.width / image.height;
    if ((imgAspect - frameAspect).abs() < 0.01) return image;

    late int outW;
    late int outH;
    if (imgAspect > frameAspect) {
      outW = image.width;
      outH = (image.width / frameAspect).round().clamp(1, 100000);
    } else {
      outH = image.height;
      outW = (image.height * frameAspect).round().clamp(1, 100000);
    }
    final canvas = img.Image(width: outW, height: outH);
    img.fill(canvas, color: img.ColorRgb8(255, 255, 255));
    final dx = ((outW - image.width) / 2).round();
    final dy = ((outH - image.height) / 2).round();
    img.compositeImage(canvas, image, dstX: dx, dstY: dy);
    return canvas;
  }

  img.Image _centerCropAspect(img.Image image, double aspectWoverH) {
    final w = image.width;
    final h = image.height;
    final current = w / h;
    if ((current - aspectWoverH).abs() < 0.001) return image;

    int cropW;
    int cropH;
    int x;
    int y;
    if (current > aspectWoverH) {
      cropH = h;
      cropW = (h * aspectWoverH).round();
      x = (w - cropW) ~/ 2;
      y = 0;
    } else {
      cropW = w;
      cropH = (w / aspectWoverH).round();
      x = 0;
      y = (h - cropH) ~/ 2;
    }
    return img.copyCrop(image, x: x, y: y, width: cropW, height: cropH);
  }

  img.Image _applyColorGrade(
    img.Image image, {
    required double brightness,
    required double contrast,
    required double saturation,
  }) {
    return img.adjustColor(
      image,
      brightness: brightness,
      contrast: contrast,
      saturation: saturation,
    );
  }

  img.Image _applyNamedFilter(img.Image image, FrameImageFilter filter) {
    switch (filter) {
      case FrameImageFilter.none:
        return image;
      case FrameImageFilter.grayscale:
        return img.grayscale(image);
      case FrameImageFilter.sepia:
        return img.sepia(image);
      case FrameImageFilter.warm:
        final s = img.sepia(image);
        return img.colorOffset(s, red: 14, green: 6, blue: -10);
      case FrameImageFilter.cool:
        return img.colorOffset(image, red: -10, green: 4, blue: 16);
      case FrameImageFilter.contrast:
        return img.adjustColor(image, contrast: 1.35, saturation: 1.05);
      case FrameImageFilter.vivid:
        return img.adjustColor(image, saturation: 1.45, contrast: 1.12);
      case FrameImageFilter.vintage:
        final v = img.sepia(image);
        return img.adjustColor(v, contrast: 0.92, brightness: 0.96);
    }
  }

  /// Nearest XT palette entry — hue‑aware so muted reds/blues survive dithering.
  static int nearestXtPaletteIndexRgb(double r, double g, double b) {
    final lum = 0.299 * r + 0.587 * g + 0.114 * b;
    final maxC = math.max(r, math.max(g, b));
    final minC = math.min(r, math.min(g, b));
    final chroma = maxC - minC;

    // Logo / screenshot primaries (e.g. MyFrame red, UI blues).
    if (r > 175 && g < 110 && b < 110 && r > g + 40 && r > b + 40) return 3;
    if (b > 175 && r < 110 && g < 140 && b > r + 40) return 5;
    if (g > 175 && r < 130 && b < 130 && g > r + 30) return 6;
    if (r > 200 && g > 200 && b < 140) return 2;

    final Iterable<int> search;
    if (chroma < 18) {
      search = lum < 132 ? const [0, 1] : const [1, 0];
    } else if (r >= g && r >= b && r - math.min(g, b) > 16) {
      search = const [3, 2, 0, 1, 5, 6];
    } else if (g >= r && g >= b && g - math.min(r, b) > 16) {
      search = const [6, 2, 0, 1, 3, 5];
    } else if (b >= r && b >= g && b - math.min(r, g) > 16) {
      search = const [5, 0, 1, 3, 6, 2];
    } else if (r > 150 && g > 150 && b < 130) {
      search = const [2, 1, 3, 0];
    } else {
      search = _xtSearchOrder;
    }

    var bestIdx = 0;
    var bestD = double.infinity;
    for (final idx in search) {
      final c = _xtPaletteColor(idx);
      final dr = r - c.r;
      final dg = g - c.g;
      final db = b - c.b;
      final d = dr * dr + dg * dg + db * db;
      if (d < bestD) {
        bestD = d;
        bestIdx = idx;
      }
    }
    return bestIdx;
  }

  /// Floyd–Steinberg error diffusion per channel on float buffers, then write indices + preview.
  _EinkPack _floydSteinbergToIndexed(img.Image image) {
    final w = image.width;
    final h = image.height;
    if (w != frameWidth || h != frameHeight) {
      throw StateError('expected ${frameWidth}x$frameHeight, got ${w}x$h');
    }
    final len = w * h;
    final wr = Float32List(len);
    final wg = Float32List(len);
    final wb = Float32List(len);

    final frame = image.frames.first;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final p = frame.getPixel(x, y);
        final i = y * w + x;
        wr[i] = p.r.toDouble();
        wg[i] = p.g.toDouble();
        wb[i] = p.b.toDouble();
      }
    }

    final flatIdx = Uint8List(len);
    final preview = img.Image(width: w, height: h);

    void diffuseError(
      int nx,
      int ny,
      double er,
      double eg,
      double eb,
      double f,
    ) {
      if (nx < 0 || nx >= w || ny < 0 || ny >= h) return;
      final j = ny * w + nx;
      wr[j] += er * f;
      wg[j] += eg * f;
      wb[j] += eb * f;
    }

    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final i = y * w + x;

        final oldR = wr[i].clamp(0.0, 255.0);
        final oldG = wg[i].clamp(0.0, 255.0);
        final oldB = wb[i].clamp(0.0, 255.0);

        final idx = nearestXtPaletteIndexRgb(oldR, oldG, oldB);
        final pal = _xtPaletteColor(idx);
        final nr = pal.r.toDouble();
        final ng = pal.g.toDouble();
        final nb = pal.b.toDouble();

        flatIdx[i] = idx & 0xFF;
        preview.setPixelRgb(x, y, pal.r, pal.g, pal.b);

        wr[i] = nr;
        wg[i] = ng;
        wb[i] = nb;

        final er = oldR - nr;
        final eg = oldG - ng;
        final eb = oldB - nb;

        diffuseError(x + 1, y, er, eg, eb, _fs7);
        diffuseError(x - 1, y + 1, er, eg, eb, _fs3);
        diffuseError(x, y + 1, er, eg, eb, _fs5);
        diffuseError(x + 1, y + 1, er, eg, eb, _fs1);
      }
    }

    return _EinkPack(flatIdx: flatIdx, preview: preview);
  }

  Uint8List _packHalfNibbles(List<int> nibbles) {
    assert(nibbles.length == _nibblesPerHalf);
    final out = Uint8List(_packedHalfLen);
    var o = 0;
    for (var i = 0; i < _nibblesPerHalf; i += 2, o++) {
      final hi = nibbles[i] & 0xF;
      final lo = nibbles[i + 1] & 0xF;
      out[o] = (hi << 4) | lo;
    }
    return out;
  }

  _BinOut _buildXt13e6Bin(_EinkPack eink) {
    final left = <int>[];
    final right = <int>[];
    for (var y = 0; y < frameHeight; y++) {
      for (var x = 0; x < _halfW; x++) {
        left.add(eink.idxAt(x, y));
      }
      for (var x = _halfW; x < frameWidth; x++) {
        right.add(eink.idxAt(x, y));
      }
    }
    final leftPacked = _packHalfNibbles(left);
    final rightPacked = _packHalfNibbles(right);

    final out = Uint8List(_xtBinTotalBytes);
    final bd = ByteData.sublistView(out);
    bd.setUint16(0, frameWidth, Endian.big);
    bd.setUint16(2, frameHeight, Endian.big);
    out.setAll(4, leftPacked);
    out.setAll(4 + _packedHalfLen, rightPacked);
    assert(out.length == _xtBinTotalBytes);
    return _BinOut(bytes: out);
  }
}

enum FrameImageFilter {
  none,
  grayscale,
  sepia,
  warm,
  cool,
  contrast,
  vivid,
  vintage,
}

class ProcessedFrameResult {
  ProcessedFrameResult({
    required this.frameJpeg,
    required this.einkPreviewJpeg,
    required this.binPayload,
    required this.crc32,
  });

  final Uint8List frameJpeg;
  final Uint8List einkPreviewJpeg;
  final Uint8List binPayload;
  final int crc32;
}

class _EinkPack {
  _EinkPack({required this.flatIdx, required this.preview});

  final Uint8List flatIdx;
  final img.Image preview;

  int idxAt(int x, int y) => flatIdx[y * ImageProcessorService.frameWidth + x];
}

class _BinOut {
  _BinOut({required this.bytes});

  final Uint8List bytes;
}
