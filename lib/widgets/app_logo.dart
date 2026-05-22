import 'package:flutter/material.dart';

import '../constants/brand_assets.dart';

/// MyFrame branding using the real red/white app icon artwork.
class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.size = 56,
    this.fit = BoxFit.contain,
  });

  /// Width and height of the logo bounds.
  final double size;

  /// [BoxFit.contain] keeps the artwork readable.
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        BrandAssets.logoPathPng,
        fit: fit,
        semanticLabel: 'MyFrame logo',
        errorBuilder: (context, _, __) => Center(
          child: Text(
            'MF',
            style: TextStyle(
              color: cs.primary,
              fontWeight: FontWeight.w900,
              fontSize: size * 0.38,
            ),
          ),
        ),
      ),
    );
  }
}
