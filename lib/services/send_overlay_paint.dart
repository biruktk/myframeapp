import 'package:image/image.dart' as img;

import '../models/send_overlay_options.dart';

/// Overlay bar for send/export (pure image ops — safe inside [compute]).
img.Image drawSendOverlayOnImage(
  img.Image source,
  SendOverlayOptions overlay, {
  required String locationText,
}) {
  if (!overlay.hasAnyOverlay) return source;
  final out = img.copyCrop(source, x: 0, y: 0, width: source.width, height: source.height);
  final now = DateTime.now();
  const step = 34;
  final barH = overlay.customText.trim().isNotEmpty ? 168.0 : 148.0;
  var y = out.height - barH.toInt() + 22;
  final bg = img.ColorRgba8(0, 0, 0, 120);
  // Full-bleed bar (no side/bottom gutter — inset used to read like a border on prints).
  img.fillRect(
    out,
    x1: 0,
    y1: out.height - barH.toInt(),
    x2: out.width,
    y2: out.height,
    color: bg,
  );
  if (overlay.customText.trim().isNotEmpty) {
    img.drawString(
      out,
      overlay.customText.trim(),
      font: img.arial24,
      y: y,
      color: img.ColorRgb8(135, 206, 235),
    );
    y += step;
  }
  if (overlay.showGreeting) {
    final greet = (overlay.greetingCustom != null && overlay.greetingCustom!.trim().isNotEmpty)
        ? overlay.greetingCustom!.trim()
        : 'With love from MyFrame';
    img.drawString(
      out,
      greet,
      font: img.arial24,
      y: y,
      color: img.ColorRgb8(255, 235, 130),
    );
    y += step;
  }
  if (overlay.showLocation) {
    img.drawString(
      out,
      locationText,
      font: img.arial24,
      y: y,
      color: img.ColorRgb8(220, 220, 220),
    );
    y += step;
  }
  if (overlay.showDate) {
    img.drawString(
      out,
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
      font: img.arial24,
      y: y,
      color: img.ColorRgb8(255, 255, 255),
    );
  }
  return out;
}
