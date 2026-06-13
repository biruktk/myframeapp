import 'package:flutter/material.dart';

import 'splash_branding_icon.dart';

/// Splash-style branding: app icon + “My” / “Frame” wordmark.
class MyFrameBrandingLockup extends StatelessWidget {
  const MyFrameBrandingLockup({
    super.key,
    this.width = 260,
  });

  final double width;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final iconSize = width * 0.46;
    final wordmarkSize = width * 0.13;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SplashBrandingIcon(size: iconSize),
        SizedBox(height: width * 0.06),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: TextStyle(
              fontSize: wordmarkSize,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
            children: [
              TextSpan(
                text: 'My',
                style: TextStyle(color: Color(0xFFD91E1E)),
              ),
              TextSpan(
                text: 'Frame',
                style: TextStyle(color: cs.onSurface),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
