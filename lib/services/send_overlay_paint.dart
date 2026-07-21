import 'dart:math' as math;

import 'package:image/image.dart' as img;

import '../models/send_overlay_options.dart';

img.ColorRgb8 _rgbFromArgb(int argb) {
  final r = (argb >> 16) & 0xFF;
  final g = (argb >> 8) & 0xFF;
  final b = argb & 0xFF;
  return img.ColorRgb8(r, g, b);
}

void _drawCenteredBarLine(
  img.Image out,
  String text, {
  required img.BitmapFont font,
  required img.ColorRgb8 color,
  required int y,
}) {
  // Approximate glyph width for arial24 so text sits center in the bar
  // (matches the E-ink Preview dialog look).
  final approxW = (text.length * 13).clamp(1, out.width);
  final x = ((out.width - approxW) / 2).round().clamp(0, out.width - 1);
  img.drawString(out, text, font: font, x: x, y: y, color: color);
}

void _drawSticker(
  img.Image out,
  String sticker, {
  double alignX = 0.62,
  double alignY = 0.40,
  double stickerSize = 28,
}) {
  final cx = (out.width * alignX).round();
  final cy = (out.height * alignY).round();
  // Smaller default than before (~width/20 at size 28).
  final scale = (stickerSize / 28).clamp(0.5, 2.5);
  final r = math.max(14, (out.width / 20 * scale).round());
  final red = img.ColorRgb8(229, 37, 42);
  final yellow = img.ColorRgb8(255, 220, 0);
  final blue = img.ColorRgb8(30, 90, 255);
  final green = img.ColorRgb8(20, 180, 70);
  final black = img.ColorRgb8(20, 20, 20);

  switch (sticker) {
    case '♥':
      img.fillCircle(out, x: cx - r ~/ 2, y: cy - r ~/ 5, radius: (r * 0.55).round(), color: red);
      img.fillCircle(out, x: cx + r ~/ 2, y: cy - r ~/ 5, radius: (r * 0.55).round(), color: red);
      for (var i = 0; i < r; i++) {
        final half = r - i;
        img.drawLine(
          out,
          x1: cx - half,
          y1: cy + i ~/ 2,
          x2: cx + half,
          y2: cy + i ~/ 2,
          color: red,
          thickness: 2,
        );
      }
      break;
    case '★': {
      final ir = (r * 0.45).round();
      final pts = <img.Point>[];
      for (var i = 0; i < 10; i++) {
        final angle = (i * math.pi) / 5 - math.pi / 2;
        final rad = i.isEven ? r : ir;
        pts.add(img.Point(cx + (rad * math.cos(angle)).round(), cy + (rad * math.sin(angle)).round()));
      }
      img.fillPolygon(out, vertices: pts, color: yellow);
      img.drawPolygon(out, vertices: pts, color: black);
      break;
    }
    case '☀': {
      final rayR = (r * 0.5).round();
      final pts = <img.Point>[];
      for (var i = 0; i < 12; i++) {
        final angle = (i * math.pi * 2) / 12 - math.pi / 2;
        final tipR = i.isEven ? r : rayR;
        pts.add(img.Point(cx + (tipR * math.cos(angle)).round(), cy + (tipR * math.sin(angle)).round()));
      }
      img.fillPolygon(out, vertices: pts, color: yellow);
      img.fillCircle(out, x: cx, y: cy, radius: (r * 0.55).round(), color: yellow);
      img.drawCircle(out, x: cx, y: cy, radius: (r * 0.55).round(), color: black);
      break;
    }
    case '●':
      img.fillCircle(out, x: cx, y: cy, radius: r, color: blue);
      break;
    case '▲':
      for (var i = 0; i < r * 2; i++) {
        final half = ((i / (r * 2)) * r).round();
        img.drawLine(
          out,
          x1: cx - half,
          y1: cy - r + i,
          x2: cx + half,
          y2: cy - r + i,
          color: green,
          thickness: 2,
        );
      }
      break;
    case '✚':
      img.fillRect(out, x1: cx - r ~/ 4, y1: cy - r, x2: cx + r ~/ 4, y2: cy + r, color: red);
      img.fillRect(out, x1: cx - r, y1: cy - r ~/ 4, x2: cx + r, y2: cy + r ~/ 4, color: red);
      break;
    case '→':
      img.drawLine(out, x1: cx - r, y1: cy, x2: cx + r, y2: cy, color: black, thickness: 6);
      img.drawLine(out, x1: cx + r ~/ 3, y1: cy - r ~/ 2, x2: cx + r, y2: cy, color: black, thickness: 6);
      img.drawLine(out, x1: cx + r ~/ 3, y1: cy + r ~/ 2, x2: cx + r, y2: cy, color: black, thickness: 6);
      break;
    case '◖':
      img.fillCircle(out, x: cx, y: cy, radius: r, color: black);
      img.fillCircle(out, x: cx, y: cy, radius: (r * 0.7).round(), color: img.ColorRgb8(255, 255, 255));
      break;
    default:
      img.fillCircle(out, x: cx, y: cy, radius: r, color: red);
  }
}

/// Overlay for send/export — full-bleed gray bar at the bottom, text centered
/// (same look as the E-ink Preview dialog). Stickers on the photo.
img.Image drawSendOverlayOnImage(
  img.Image source,
  SendOverlayOptions overlay, {
  required String locationText,
}) {
  if (!overlay.hasAnyOverlay) return source;
  final out = img.copyCrop(source, x: 0, y: 0, width: source.width, height: source.height);
  final w = out.width;
  final h = out.height;

  // Border (drawn before any bar)
  switch (overlay.borderStyle) {
    case 'thinBlack':
      img.drawRect(out, x1: 0, y1: 0, x2: w - 1, y2: h - 1, color: img.ColorRgb8(0, 0, 0), thickness: 2);
      break;
    case 'thickWhite':
      img.drawRect(out, x1: 0, y1: 0, x2: w - 1, y2: h - 1, color: img.ColorRgb8(255, 255, 255), thickness: 10);
      break;
    case 'polaroid':
      img.drawRect(out, x1: 0, y1: 0, x2: w - 1, y2: h - 1, color: img.ColorRgb8(255, 255, 255), thickness: 10);
      img.fillRect(out, x1: 0, y1: h - 28, x2: w, y2: h, color: img.ColorRgb8(255, 255, 255));
      break;
    case 'film':
      img.drawRect(out, x1: 0, y1: 0, x2: w - 1, y2: h - 1, color: img.ColorRgb8(0, 0, 0), thickness: 12);
      break;
    case 'double':
      img.drawRect(out, x1: 0, y1: 0, x2: w - 1, y2: h - 1, color: img.ColorRgb8(20, 20, 20), thickness: 4);
      img.drawRect(out, x1: 8, y1: 8, x2: w - 9, y2: h - 9, color: img.ColorRgb8(255, 255, 255), thickness: 2);
      break;
    case 'rounded':
      img.drawRect(out, x1: 2, y1: 2, x2: w - 3, y2: h - 3, color: img.ColorRgba8(0, 0, 0, 50), thickness: 2);
      break;
  }

  final sticker = overlay.centerSticker.trim();
  if (sticker.isNotEmpty) {
    _drawSticker(
      out,
      sticker,
      alignX: overlay.stickerAlignX,
      alignY: overlay.stickerAlignY,
      stickerSize: overlay.stickerSize,
    );
  }

  final now = DateTime.now();
  final lines = <_BarLine>[];
  if (overlay.showWeather && overlay.weatherText.trim().isNotEmpty) {
    lines.add(_BarLine(overlay.weatherText.trim(), img.ColorRgb8(255, 255, 255)));
  } else if (overlay.showLocation && locationText.trim().isNotEmpty) {
    lines.add(_BarLine(locationText.trim(), img.ColorRgb8(220, 220, 220)));
  }
  if (overlay.showDate) {
    lines.add(
      _BarLine(
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
        img.ColorRgb8(255, 255, 255),
      ),
    );
  }
  if (overlay.centerText.trim().isNotEmpty) {
    lines.add(_BarLine(overlay.centerText.trim(), _rgbFromArgb(overlay.centerTextColor)));
  }
  if (overlay.showGreeting) {
    final greet = (overlay.greetingCustom != null && overlay.greetingCustom!.trim().isNotEmpty)
        ? overlay.greetingCustom!.trim()
        : 'With love from MyFrame';
    lines.add(_BarLine(greet, img.ColorRgb8(255, 235, 130)));
  }
  if (overlay.customText.trim().isNotEmpty) {
    lines.add(_BarLine(overlay.customText.trim(), img.ColorRgb8(135, 206, 235)));
  }

  if (lines.isEmpty) return out;

  const step = 28;
  final barH = math.max(96.0, 28.0 + lines.length * step);
  var y = out.height - barH.toInt() + 14;
  img.fillRect(
    out,
    x1: 0,
    y1: out.height - barH.toInt(),
    x2: out.width,
    y2: out.height,
    color: img.ColorRgba8(0, 0, 0, 120),
  );
  for (final line in lines) {
    _drawCenteredBarLine(
      out,
      line.text,
      font: img.arial24,
      color: line.color,
      y: y,
    );
    y += step;
  }
  return out;
}

class _BarLine {
  const _BarLine(this.text, this.color);
  final String text;
  final img.ColorRgb8 color;
}
