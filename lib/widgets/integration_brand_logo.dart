import 'package:flutter/material.dart';

/// Google Photos and iCloud brand marks for Settings -> Integrations.
class IntegrationBrandLogo extends StatelessWidget {
  const IntegrationBrandLogo.googlePhotos({super.key, this.size = 36})
    : _kind = _Kind.googlePhotos;

  const IntegrationBrandLogo.icloud({super.key, this.size = 36})
    : _kind = _Kind.icloud;

  final double size;
  final _Kind _kind;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _kind == _Kind.googlePhotos
            ? const _GooglePhotosLogoPainter()
            : const _ICloudLogoPainter(),
      ),
    );
  }
}

enum _Kind { googlePhotos, icloud }

class _GooglePhotosLogoPainter extends CustomPainter {
  const _GooglePhotosLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w * 0.5, h * 0.5);
    final r = w * 0.21;

    canvas.drawPath(
      Path()..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.38, h * 0.04, w * 0.24, h * 0.46),
          Radius.circular(w * 0.12),
        ),
      ),
      Paint()..color = const Color(0xFF4285F4),
    );
    canvas.drawPath(
      Path()..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.5, h * 0.38, w * 0.46, h * 0.24),
          Radius.circular(w * 0.12),
        ),
      ),
      Paint()..color = const Color(0xFF34A853),
    );
    canvas.drawPath(
      Path()..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.38, h * 0.5, w * 0.24, h * 0.46),
          Radius.circular(w * 0.12),
        ),
      ),
      Paint()..color = const Color(0xFFFBBC04),
    );
    canvas.drawPath(
      Path()..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.04, h * 0.38, w * 0.46, h * 0.24),
          Radius.circular(w * 0.12),
        ),
      ),
      Paint()..color = const Color(0xFFEA4335),
    );
    canvas.drawCircle(center, r, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ICloudLogoPainter extends CustomPainter {
  const _ICloudLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()..color = const Color(0xFF0A84FF);
    final path = Path()
      ..moveTo(w * 0.27, h * 0.78)
      ..cubicTo(w * 0.12, h * 0.78, w * 0.02, h * 0.67, w * 0.02, h * 0.53)
      ..cubicTo(w * 0.02, h * 0.39, w * 0.14, h * 0.28, w * 0.28, h * 0.29)
      ..cubicTo(w * 0.34, h * 0.14, w * 0.48, h * 0.06, w * 0.64, h * 0.1)
      ..cubicTo(w * 0.79, h * 0.14, w * 0.89, h * 0.27, w * 0.9, h * 0.43)
      ..cubicTo(w * 0.98, h * 0.48, w, h * 0.57, w * 0.97, h * 0.65)
      ..cubicTo(w * 0.93, h * 0.74, w * 0.84, h * 0.78, w * 0.73, h * 0.78)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
