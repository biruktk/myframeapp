import 'package:flutter/material.dart';

import '../constants/brand_assets.dart';

/// MyFrame branding using the real red/white app icon artwork.
class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.size = 56,
    this.fit = BoxFit.contain,
    this.iconOnly = false,
    this.rounded = true,
  });

  /// Width and height of the logo bounds.
  final double size;

  /// [BoxFit.contain] keeps the artwork readable.
  final BoxFit fit;

  /// When true, shows the red app symbol only (login / toolbar), not the full lockup JPEG.
  final bool iconOnly;

  /// iOS-style squircle clip for the red app icon (splash, login, onboarding).
  final bool rounded;

  static const _brandRed = Color(0xFFD91E1E);

  @override
  Widget build(BuildContext context) {
    final asset = iconOnly ? BrandAssets.splashIconPath : BrandAssets.logoPathPng;
    final image = Image.asset(
      asset,
      fit: fit,
      width: size,
      height: size,
      filterQuality: FilterQuality.high,
      gaplessPlayback: true,
      semanticLabel: 'MyFrame logo',
      errorBuilder: (context, _, __) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _brandRed,
          borderRadius: rounded ? BorderRadius.circular(size * 0.223) : null,
        ),
        child: Icon(Icons.photo_outlined, color: Colors.white, size: size * 0.5),
      ),
    );

    if (!iconOnly || !rounded) {
      return SizedBox(width: size, height: size, child: image);
    }

    final radius = size * 0.223;
    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: image,
      ),
    );
  }
}
