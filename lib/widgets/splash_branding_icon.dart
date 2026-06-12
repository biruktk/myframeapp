import 'package:flutter/material.dart';

import '../constants/splash_branding.dart';

/// Red MyFrame app icon for splash / auth headers (always visible on white).
class SplashBrandingIcon extends StatelessWidget {
  const SplashBrandingIcon({
    super.key,
    this.size = 148,
  });

  final double size;

  @override
  Widget build(BuildContext context) {
    final bytes = SplashBranding.iconPngBytes;
    final radius = size * 0.223;

    if (bytes != null && bytes.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.memory(
          bytes,
          width: size,
          height: size,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          gaplessPlayback: true,
          semanticLabel: 'MyFrame',
          errorBuilder: (_, __, ___) => _FallbackIcon(size: size),
        ),
      );
    }

    return _FallbackIcon(size: size);
  }
}

class _FallbackIcon extends StatelessWidget {
  const _FallbackIcon({required this.size});

  final double size;

  static const _brandRed = Color(0xFFD91E1E);

  @override
  Widget build(BuildContext context) {
    final radius = size * 0.223;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _brandRed,
        borderRadius: BorderRadius.circular(radius),
      ),
      alignment: Alignment.center,
      child: Icon(Icons.photo_outlined, color: Colors.white, size: size * 0.44),
    );
  }
}
