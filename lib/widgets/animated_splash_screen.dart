import 'dart:math' show sin, pi;

import 'package:flutter/material.dart';
import '../constants/brand_assets.dart';
import '../constants/splash_branding.dart';

class AnimatedSplashScreen extends StatefulWidget {
  const AnimatedSplashScreen({super.key, required this.onComplete});
  final VoidCallback onComplete;

  @override
  State<AnimatedSplashScreen> createState() => _AnimatedSplashScreenState();
}

class _AnimatedSplashScreenState extends State<AnimatedSplashScreen>
    with SingleTickerProviderStateMixin {
  /// Compact but readable square mark (was 96; bumped for presence).
  static const _iconSize = 118.0;

  late final AnimationController _controller;

  // Stage 1 – Fade In (0–300ms / 0–0.13)
  late final Animation<double> _logoOpacity;
  late final Animation<double> _logoEntranceScale;
  late final Animation<Offset> _textSlideUp;
  late final Animation<double> _textOpacity;

  // Stage 3 – Soft focus (1200–1700ms / 0.52–0.74)
  late final Animation<double> _textFadeOut;
  late final Animation<double> _logoFocusScale;

  // Stage 4 – Settle (1700–2100ms / 0.74–0.91) — gentle scale, no hero zoom
  late final Animation<double> _settleScale;

  // Stage 5 – Exit (2100–2300ms / 0.91–1.0)
  late final Animation<double> _exitOpacity;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2300),
    );

    _logoOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.13, curve: Curves.easeOutCubic),
      ),
    );
    _logoEntranceScale = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.13, curve: Curves.easeOutCubic),
      ),
    );
    _textSlideUp = Tween<Offset>(
      begin: const Offset(0, 0.28),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.13, curve: Curves.easeOutCubic),
      ),
    );
    _textOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.13, curve: Curves.easeOutCubic),
      ),
    );

    _textFadeOut = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.52, 0.74, curve: Curves.easeOutCubic),
      ),
    );
    // Mild focus only — avoids exploding into the tilted frame artwork.
    _logoFocusScale = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.52, 0.74, curve: Curves.easeInOutCubic),
      ),
    );

    _settleScale = Tween<double>(begin: 1.06, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.74, 0.91, curve: Curves.easeInOutCubic),
      ),
    );

    _exitOpacity = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.91, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete();
      }
    });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final p = _controller.value;
        final inStage1 = p < 0.13;
        final inStage2 = p >= 0.13 && p < 0.52;
        final inStage3 = p >= 0.52 && p < 0.74;
        final inStage4 = p >= 0.74 && p < 0.91;
        final inStage5 = p >= 0.91;

        // Stage 2: one slow breath using sine wave
        double floatDy = 0;
        if (inStage2) {
          final t = (p - 0.13) / (0.52 - 0.13);
          floatDy = sin(t * pi * 2) * -5;
        }

        final logoScale = inStage1
            ? _logoEntranceScale.value
            : inStage3
                ? _logoFocusScale.value
                : (inStage4 || inStage5 ? _settleScale.value : 1.0);

        final logoOpacity = inStage1 ? _logoOpacity.value : 1.0;
        final textOpacity = inStage1
            ? _textOpacity.value
            : (inStage2 ? 1.0 : _textFadeOut.value);

        final textOffset = inStage1
            ? _textSlideUp.value
            : (inStage2 ? Offset(0, floatDy * 0.3) : Offset.zero);

        final overallOpacity = inStage5 ? _exitOpacity.value : 1.0;
        final spacing = inStage2 ? 18 + floatDy * 0.25 : 18.0;

        return Scaffold(
          backgroundColor: Colors.white,
          body: RepaintBoundary(
            child: Opacity(
              opacity: overallOpacity.clamp(0.0, 1.0),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Transform.translate(
                      offset: Offset(0, floatDy),
                      child: Opacity(
                        opacity: logoOpacity.clamp(0.0, 1.0),
                        child: Transform.scale(
                          scale: logoScale,
                          alignment: Alignment.center,
                          child: const _SplashIcon(size: _iconSize),
                        ),
                      ),
                    ),
                    SizedBox(height: spacing),
                    Opacity(
                      opacity: textOpacity.clamp(0.0, 1.0),
                      child: Transform.translate(
                        offset: textOffset,
                        child: const _MyFrameWordmark(fontSize: 30),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SplashIcon extends StatelessWidget {
  const _SplashIcon({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    final bytes = SplashBranding.iconPngBytes;
    // Squircle that still reads as a full square mark (iOS-like ~22%).
    final radius = size * 0.22;

    Widget image;
    if (bytes != null && bytes.isNotEmpty) {
      image = Image.memory(
        bytes,
        width: size,
        height: size,
        fit: BoxFit.cover,
        alignment: Alignment.center,
        filterQuality: FilterQuality.high,
        gaplessPlayback: true,
        semanticLabel: 'MyFrame',
        errorBuilder: (_, __, ___) => const _AssetImage(),
      );
    } else {
      image = const _AssetImage();
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: image,
      ),
    );
  }
}

class _AssetImage extends StatelessWidget {
  const _AssetImage();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      BrandAssets.appIconPath,
      fit: BoxFit.cover,
      alignment: Alignment.center,
      filterQuality: FilterQuality.high,
      gaplessPlayback: true,
      semanticLabel: 'MyFrame',
      errorBuilder: (_, __, ___) => const _FallbackIcon(),
    );
  }
}

class _FallbackIcon extends StatelessWidget {
  const _FallbackIcon();

  static const _brandRed = Color(0xFFD91E1E);

  @override
  Widget build(BuildContext context) {
    const size = 118.0;
    const radius = size * 0.22;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _brandRed,
        borderRadius: BorderRadius.circular(radius),
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.photo_outlined, color: Colors.white, size: 42),
    );
  }
}

class _MyFrameWordmark extends StatelessWidget {
  const _MyFrameWordmark({required this.fontSize});
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          height: 1,
          fontFamily: 'Roboto',
        ),
        children: const [
          TextSpan(
            text: 'My',
            style: TextStyle(color: Color(0xFFD91E1E)),
          ),
          TextSpan(
            text: 'Frame',
            style: TextStyle(color: Colors.black),
          ),
        ],
      ),
    );
  }
}
