import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';

/// Educational coach mark that highlights a target widget (the Wi‑Fi password
/// field) with a dark scrim, a spotlight cutout, a glowing accent border, a
/// directional arrow, and a helper bubble + "Got it" button.
///
/// Rendered via an [OverlayEntry] so it can sit *above* the app's own
/// `Scaffold`, and measure the target's global rect to punch a hole exactly
/// around it. Dismissing (tap anywhere outside the target, or the "Got it"
/// button) removes the overlay and focuses the password field.
class WifiPasswordGuideOverlay {
  WifiPasswordGuideOverlay._();

  static const _scrim = Color(0xA6000000); // rgba(0,0,0,0.65)
  static const _accent = Color(0xFFE53535);

  static OverlayEntry build({
    required BuildContext context,
    required GlobalKey targetKey,
    required VoidCallback onDismiss,
  }) {
    final s = AppStrings.of(context);
    return OverlayEntry(
      builder: (ctx) => _GuideOverlayContent(
        targetKey: targetKey,
        prompt: s.wifiPasswordGuidePrompt,
        gotIt: s.wifiPasswordGuideGotIt,
        onDismiss: onDismiss,
      ),
    );
  }
}

class _GuideOverlayContent extends StatefulWidget {
  const _GuideOverlayContent({
    required this.targetKey,
    required this.prompt,
    required this.gotIt,
    required this.onDismiss,
  });

  final GlobalKey targetKey;
  final String prompt;
  final String gotIt;
  final VoidCallback onDismiss;

  @override
  State<_GuideOverlayContent> createState() => _GuideOverlayContentState();
}

class _GuideOverlayContentState extends State<_GuideOverlayContent> {
  Rect? _targetRect;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  void _measure() {
    final render = widget.targetKey.currentContext?.findRenderObject();
    if (render is! RenderBox || !render.hasSize) return;
    final topLeft = render.localToGlobal(Offset.zero);
    if (!mounted) return;
    setState(() {
      _targetRect = topLeft & render.size;
    });
  }

  void _dismiss() {
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final screen = Offset(media.size.width, media.size.height);
    final target = _targetRect;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _dismiss,
      child: Stack(
        children: [
          // Scrim with spotlight cutout around the target.
          Positioned.fill(
            child: CustomPaint(
              painter: _SpotlightPainter(target: target),
            ),
          ),
          // Glowing accent border + arrow + bubble anchored to the target.
          if (target != null) _buildGuide(target, screen),
        ],
      ),
    );
  }

  Widget _buildGuide(Rect target, Offset screen) {
    // Padding around the cutout.
    final pad = 10.0;
    final focusRect =
        target.inflate(pad).intersect(Rect.fromLTWH(0, 0, screen.dx, screen.dy));

    final bubbleAbove = focusRect.top > 220;
    final bubbleWidth = (mediaTextScale(context) * 280).clamp(230.0, 320.0);
    final bubbleLeft =
        (focusRect.center.dx - bubbleWidth / 2).clamp(16.0, screen.dx - bubbleWidth - 16.0);
    final bubbleTop = bubbleAbove
        ? (focusRect.top - 132).clamp(12.0, screen.dy - 200)
        : (focusRect.bottom + 56).clamp(12.0, screen.dy - 180);
    final arrowDown = bubbleAbove; // arrow points down at the target
    final arrowCenterX = focusRect.center.dx.clamp(24.0, screen.dx - 24.0);

    return Stack(
      children: [
        // Glowing accent rounded border hugging the target.
        Positioned.fromRect(
          rect: focusRect,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: WifiPasswordGuideOverlay._accent, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: WifiPasswordGuideOverlay._accent.withValues(alpha: 0.5),
                    blurRadius: 22,
                    spreadRadius: 3,
                  ),
                ],
              ),
            ),
          ),
        ),
        // Text bubble.
        Positioned(
          left: bubbleLeft,
          top: bubbleTop,
          width: bubbleWidth,
          child: _Bubble(
            prompt: widget.prompt,
            gotIt: widget.gotIt,
            onGotIt: _dismiss,
          ),
        ),
        // Directional arrow between the bubble and the target.
        Positioned(
          left: arrowCenterX - 14,
          top: bubbleAbove
              ? (focusRect.top - 24).clamp(0.0, screen.dy)
              : (bubbleTop + 96).clamp(0.0, screen.dy),
          child: IgnorePointer(
            child: CustomPaint(
              size: const Size(28, 28),
              painter: _ArrowPainter(
                accent: WifiPasswordGuideOverlay._accent,
                pointingDown: arrowDown,
              ),
            ),
          ),
        ),
      ],
    );
  }

  double mediaTextScale(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(14) / 14.0;
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.prompt,
    required this.gotIt,
    required this.onGotIt,
  });

  final String prompt;
  final String gotIt;
  final VoidCallback onGotIt;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 6,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              prompt,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF222222),
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: onGotIt,
              style: FilledButton.styleFrom(
                backgroundColor: WifiPasswordGuideOverlay._accent,
                foregroundColor: Colors.white,
                minimumSize: const Size(88, 34),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(17),
                ),
              ),
              child: Text(gotIt, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Paints a full-screen dark scrim with a "cutout" (clear blob) around the
/// target rect using BlendMode.clear inside a saveLayer.
class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter({required this.target});

  final Rect? target;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.saveLayer(rect, Paint());
    // Dark scrim.
    canvas.drawRect(rect, Paint()..color = WifiPasswordGuideOverlay._scrim);
    // Punch a hole over the target (rounded, with a soft feather).
    if (target != null) {
      final cut = target!.inflate(10);
      final rrect = RRect.fromRectAndRadius(cut, const Radius.circular(10));
      canvas.drawRRect(
        rrect,
        Paint()
          ..blendMode = BlendMode.clear
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter old) =>
      old.target != target;
}

/// Hand-drawn-style arrow pointing down (toward the field) or up.
class _ArrowPainter extends CustomPainter {
  _ArrowPainter({required this.accent, required this.pointingDown});

  final Color accent;
  final bool pointingDown;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = accent
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final midX = size.width / 2;
    final originY = pointingDown ? 2.0 : size.height - 2.0;
    final tipY = pointingDown ? size.height - 2.0 : 2.0;
    canvas.drawLine(Offset(midX, originY), Offset(midX, tipY), paint);
    // Arrow head.
    final headY = tipY;
    canvas.drawLine(Offset(midX, headY), Offset(midX - 7, headY - (pointingDown ? 8 : -8)), paint);
    canvas.drawLine(Offset(midX, headY), Offset(midX + 7, headY - (pointingDown ? 8 : -8)), paint);
  }

  @override
  bool shouldRepaint(covariant _ArrowPainter old) =>
      old.pointingDown != pointingDown || old.accent != accent;
}

/// Lightweight in-flow coach mark for the Wi‑Fi password field: a gently
/// bouncing brand-red pill ("Enter Wi-Fi password here") with a tap-hand icon,
/// placed directly above the input. It auto-dismisses the moment the field
/// gains focus or the user types anything, and reappears whenever the field is
/// empty + unfocused again (no "Got it" step, unlike [WifiPasswordGuideOverlay]).
class WifiPasswordCoachMark extends StatefulWidget {
  const WifiPasswordCoachMark({
    super.key,
    required this.controller,
    required this.focusNode,
    this.visible = true,
  });

  final TextEditingController controller;
  final FocusNode focusNode;

  /// Parent-level override (e.g. hide while the full spotlight overlay shows).
  final bool visible;

  @override
  State<WifiPasswordCoachMark> createState() => _WifiPasswordCoachMarkState();
}

class _WifiPasswordCoachMarkState extends State<WifiPasswordCoachMark>
    with SingleTickerProviderStateMixin {
  static const _accent = Color(0xFFE53935);

  late final AnimationController _bounce;
  late final Animation<double> _offset;

  @override
  void initState() {
    super.initState();
    _bounce = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _offset = Tween<double>(begin: 0, end: -6).animate(
      CurvedAnimation(parent: _bounce, curve: Curves.easeInOut),
    );
    widget.controller.addListener(_onChanged);
    widget.focusNode.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    widget.focusNode.removeListener(_onChanged);
    _bounce.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  bool get _shouldShow =>
      widget.visible &&
      !widget.focusNode.hasFocus &&
      widget.controller.text.trim().isEmpty;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);

    if (!_shouldShow) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _offset,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, _offset.value),
        child: child,
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: _accent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _accent.withValues(alpha: 0.3),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.touch_app_rounded, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                s.wifiPasswordCoachHint,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

