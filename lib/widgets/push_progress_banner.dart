import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../services/upload_queue_controller.dart';

/// Above the navigator, so a background share never needs to change routes.
class PushProgressOverlay extends StatelessWidget {
  const PushProgressOverlay({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      child,
      const Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: SafeArea(
          bottom: false,
          child: Material(
            type: MaterialType.transparency,
            child: PushProgressBanner(),
          ),
        ),
      ),
    ],
  );
}

/// Floating progress capsule pinned beneath the AppBar / tab selector that
/// reports the live status of an async image push.
///
/// Designed as a modern, compact 36px pill: frosted neutral surface, hairline
/// border, smooth animated fill bar and a small status indicator. Auto-dismisses
/// with a slide-up + fade once the hardware confirms `play_ack` (completed), or
/// fades to a neutral error pill on failure.
class PushProgressBanner extends StatelessWidget {
  const PushProgressBanner({super.key});

  static const _neutral = Color(0xFF1F1F1F);
  static const _green = Color(0xFF2E9E5B);

  String _label(AppStrings s, PushJobView job) {
    if (job.label != null) return job.label!;
    switch (job.stage) {
      case PushJobStage.queued:
        return s.pushStageQueued;
      case PushJobStage.uploading:
        return s.pushStageUploading;
      case PushJobStage.downloading:
        return s.pushStageDownloading;
      case PushJobStage.refreshing:
        return s.pushStageRefreshing;
      case PushJobStage.completed:
        return s.pushStageCompleted;
      case PushJobStage.failed:
        return s.pushStageFailed;
    }
  }

  Color _accent(PushJobStage stage, bool dark) {
    switch (stage) {
      case PushJobStage.completed:
        return _green;
      case PushJobStage.failed:
        return dark ? const Color(0xFFFCA5A5) : const Color(0xFFDC2626);
      default:
        return dark ? const Color(0xFFFCA5A5) : _neutral;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListenableBuilder(
      listenable: UploadQueueController.instance,
      builder: (context, _) {
        final job = UploadQueueController.instance.currentJob;
        if (job == null) return const SizedBox.shrink();

        final accent = _accent(job.stage, isDark);
        final isTerminal =
            job.stage == PushJobStage.completed ||
            job.stage == PushJobStage.failed;

        return AnimatedSlide(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          offset: isTerminal ? const Offset(0, 0.15) : Offset.zero,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 420),
            opacity: 1,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Container(
                height: 36,
                decoration: BoxDecoration(
                  color: cs.surface.withValues(alpha: isDark ? 0.82 : 0.94),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.6),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.25 : 0.10,
                      ),
                      blurRadius: 16,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Row content.
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Row(
                          children: [
                            _StatusIndicator(
                              stage: job.stage,
                              accent: accent,
                              dark: isDark,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _label(s, job),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: cs.onSurface,
                                  height: 1,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 180),
                              child: Text(
                                job.stage == PushJobStage.failed
                                    ? ''
                                    : '${(job.progress * 100).round()}%',
                                key: ValueKey(
                                  '${job.stage}_${job.progress.toStringAsFixed(2)}',
                                ),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: accent,
                                  height: 1,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Animated progress fill at the very bottom.
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: 3,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween<double>(
                            begin: 0,
                            end: job.progress.clamp(0.0, 1.0),
                          ),
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, _) => Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              width:
                                  (MediaQuery.of(context).size.width - 32) *
                                  value,
                              height: 3,
                              decoration: BoxDecoration(
                                color: accent.withValues(
                                  alpha: isDark ? 0.85 : 0.9,
                                ),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
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
      },
    );
  }
}

/// Small spinner / check / alert indicator.
class _StatusIndicator extends StatelessWidget {
  const _StatusIndicator({
    required this.stage,
    required this.accent,
    required this.dark,
  });

  final PushJobStage stage;
  final Color accent;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final neutral = dark ? Colors.white70 : const Color(0xFF1F1F1F);
    switch (stage) {
      case PushJobStage.completed:
        return Icon(
          Icons.check_circle_rounded,
          size: 16,
          color: _PushProgressBannerColors._green,
        );
      case PushJobStage.failed:
        return Icon(Icons.error_rounded, size: 16, color: accent);
      case PushJobStage.refreshing:
        // Pulsing moon while E-Ink refreshes.
        return Icon(Icons.bedtime_outlined, size: 15, color: neutral);
      default:
        return SizedBox(
          width: 13,
          height: 13,
          child: CircularProgressIndicator(strokeWidth: 1.8, color: neutral),
        );
    }
  }
}

class _PushProgressBannerColors {
  static const _green = Color(0xFF2E9E5B);
}
