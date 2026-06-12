import 'package:flutter/material.dart';

/// Google Drive and Dropbox brand marks for Settings → Integrations.
class IntegrationBrandLogo extends StatelessWidget {
  const IntegrationBrandLogo.googleDrive({super.key, this.size = 36})
      : _kind = _Kind.googleDrive;

  const IntegrationBrandLogo.dropbox({super.key, this.size = 36})
      : _kind = _Kind.dropbox;

  final double size;
  final _Kind _kind;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _kind == _Kind.googleDrive
            ? const _GoogleDriveLogoPainter()
            : const _DropboxLogoPainter(),
      ),
    );
  }
}

enum _Kind { googleDrive, dropbox }

class _GoogleDriveLogoPainter extends CustomPainter {
  const _GoogleDriveLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final top = Offset(w * 0.5, h * 0.12);
    final left = Offset(w * 0.12, h * 0.82);
    final right = Offset(w * 0.88, h * 0.82);
    final mid = Offset(w * 0.5, h * 0.82);

    canvas.drawPath(
      Path()
        ..moveTo(top.dx, top.dy)
        ..lineTo(right.dx, right.dy)
        ..lineTo(mid.dx, mid.dy)
        ..close(),
      Paint()..color = const Color(0xFF4285F4),
    );
    canvas.drawPath(
      Path()
        ..moveTo(top.dx, top.dy)
        ..lineTo(left.dx, left.dy)
        ..lineTo(mid.dx, mid.dy)
        ..close(),
      Paint()..color = const Color(0xFF34A853),
    );
    canvas.drawPath(
      Path()
        ..moveTo(top.dx, top.dy)
        ..lineTo(mid.dx, mid.dy)
        ..lineTo(right.dx, right.dy)
        ..lineTo(w * 0.68, h * 0.82)
        ..lineTo(w * 0.5, h * 0.58)
        ..close(),
      Paint()..color = const Color(0xFFFBBC04),
    );
    canvas.drawPath(
      Path()
        ..moveTo(top.dx, top.dy)
        ..lineTo(w * 0.32, h * 0.82)
        ..lineTo(mid.dx, mid.dy)
        ..lineTo(w * 0.5, h * 0.58)
        ..close(),
      Paint()..color = const Color(0xFFEA4335),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DropboxLogoPainter extends CustomPainter {
  const _DropboxLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF0061FF);
    final w = size.width;
    final h = size.height;
    final cx = w * 0.5;

    canvas.drawPath(
      Path()
        ..moveTo(cx, h * 0.18)
        ..lineTo(w * 0.78, h * 0.38)
        ..lineTo(cx, h * 0.58)
        ..lineTo(w * 0.22, h * 0.38)
        ..close(),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(cx, h * 0.46)
        ..lineTo(w * 0.78, h * 0.66)
        ..lineTo(cx, h * 0.86)
        ..lineTo(w * 0.22, h * 0.66)
        ..close(),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
