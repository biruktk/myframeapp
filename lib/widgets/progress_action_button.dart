import 'package:flutter/material.dart';

/// Primary action button with live progress: step counts, status text,
/// inline spinner, and an optional translucent fill bar.
class ProgressActionButton extends StatelessWidget {
  const ProgressActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.statusMessage,
    this.currentStep,
    this.totalSteps,
    this.progress,
    this.icon,
    this.height = 50,
    this.borderRadius,
    this.backgroundColor,
    this.foregroundColor,
    this.disabledBackgroundColor,
  });

  /// Idle label when not loading.
  final String label;

  /// Disabled while [isLoading] or when null.
  final VoidCallback? onPressed;

  final bool isLoading;

  /// e.g. "Sending photos" / "Configuring frame"
  final String? statusMessage;

  /// 1-based current item (playlist / batch send).
  final int? currentStep;

  /// Total items in the batch.
  final int? totalSteps;

  /// 0.0–1.0 fill; null = indeterminate (no fill bar, spinner only).
  final double? progress;

  final IconData? icon;
  final double height;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? disabledBackgroundColor;

  String get _loadingLabel {
    final base = (statusMessage ?? label).trim();
    final cur = currentStep;
    final total = totalSteps;
    if (cur != null && total != null && total > 1) {
      return '$base ($cur/$total)…';
    }
    final p = progress;
    if (p != null && p > 0 && p < 1) {
      final pct = (p * 100).round().clamp(0, 100);
      return '$base ($pct%)…';
    }
    if (base.endsWith('…') || base.endsWith('...')) return base;
    return '$base…';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = backgroundColor ?? cs.primary;
    final fg = foregroundColor ?? cs.onPrimary;
    final disabledBg =
        disabledBackgroundColor ?? bg.withValues(alpha: 0.55);
    final radius = borderRadius ?? BorderRadius.circular(12);
    final fill = progress?.clamp(0.0, 1.0);

    return SizedBox(
      width: double.infinity,
      height: height,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: radius,
          child: Ink(
            decoration: BoxDecoration(
              color: (isLoading || onPressed == null) ? disabledBg : bg,
              borderRadius: radius,
            ),
            child: ClipRRect(
              borderRadius: radius,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (isLoading && fill != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: fill,
                        child: ColoredBox(
                          color: Colors.white.withValues(alpha: 0.22),
                        ),
                      ),
                    ),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: isLoading
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    value: fill,
                                    valueColor:
                                        AlwaysStoppedAnimation<Color>(fg),
                                    backgroundColor:
                                        fg.withValues(alpha: 0.25),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Flexible(
                                  child: Text(
                                    _loadingLabel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: fg,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (icon != null) ...[
                                  Icon(icon, color: fg, size: 20),
                                  const SizedBox(width: 8),
                                ],
                                Flexible(
                                  child: Text(
                                    label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: fg,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
