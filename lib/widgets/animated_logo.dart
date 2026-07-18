import 'package:flutter/material.dart';

/// Animated MyFrame logo for splash screen / entry page
class AnimatedMyFrameLogo extends StatefulWidget {
  const AnimatedMyFrameLogo({
    super.key,
    this.size = 120,
    this.autoStart = true,
  });

  final double size;
  final bool autoStart;

  @override
  State<AnimatedMyFrameLogo> createState() => _AnimatedMyFrameLogoState();
}

class _AnimatedMyFrameLogoState extends State<AnimatedMyFrameLogo>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _frameController;
  
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _frameSlideAnimation;

  @override
  void initState() {
    super.initState();

    // Fade in animation
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );

    // Scale animation
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    );

    // "frame" slide animation
    _frameController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _frameSlideAnimation = CurvedAnimation(
      parent: _frameController,
      curve: Curves.easeOutBack,
    );

    if (widget.autoStart) {
      _startAnimation();
    }
  }

  Future<void> _startAnimation() async {
    await Future.delayed(const Duration(milliseconds: 100));
    _fadeController.forward();
    await Future.delayed(const Duration(milliseconds: 200));
    _scaleController.forward();
    await Future.delayed(const Duration(milliseconds: 300));
    _frameController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    _frameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: SizedBox(
          width: widget.size * 2.5,
          height: widget.size,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // "my" part - red color
              Text(
                'my',
                style: TextStyle(
                  fontSize: widget.size * 0.7,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFE53935), // MyFrame red
                  letterSpacing: -1,
                ),
              ),
              
              const SizedBox(width: 4),
              
              // "frame" part - animated slide in
              SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.3, 0),
                  end: Offset.zero,
                ).animate(_frameSlideAnimation),
                child: FadeTransition(
                  opacity: _frameSlideAnimation,
                  child: Text(
                    'frame',
                    style: TextStyle(
                      fontSize: widget.size * 0.7,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full splash screen with animated logo
class SplashScreenWithLogo extends StatelessWidget {
  const SplashScreenWithLogo({
    super.key,
    this.onAnimationComplete,
  });

  final VoidCallback? onAnimationComplete;

  @override
  Widget build(BuildContext context) {
    // Auto-navigate after animation
    if (onAnimationComplete != null) {
      Future.delayed(const Duration(milliseconds: 2000), () {
        if (context.mounted) {
          onAnimationComplete!();
        }
      });
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.surface,
              Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
            ],
          ),
        ),
        child: const Center(
          child: AnimatedMyFrameLogo(size: 120),
        ),
      ),
    );
  }
}
