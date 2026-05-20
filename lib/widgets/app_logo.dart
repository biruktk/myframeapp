import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../constants/brand_assets.dart';

/// MyFrame branding — SVG logo only (no box, border, or fill behind the artwork).
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
      child: SvgPicture.asset(
        BrandAssets.logoPathSvg,
        fit: fit,
        clipBehavior: Clip.none,
        semanticsLabel: 'MyFrame logo',
        placeholderBuilder: (_) => SizedBox(
          width: size,
          height: size,
          child: Center(
            child: SizedBox(
              width: size * 0.28,
              height: size * 0.28,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: cs.primary.withValues(alpha: 0.35),
              ),
            ),
          ),
        ),
        errorBuilder: (context, _, __) => SizedBox(
          width: size,
          height: size,
          child: Center(
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
      ),
    );
  }
}
