import 'package:flutter/material.dart';

/// Visual tone for [AppStatusToast] / inline status banners.
enum AppStatusTone { success, info, warning, error }

/// Small floating feedback card — title + message, soft colors, auto-dismiss.
class AppStatusToast {
  AppStatusToast._();

  static void show(
    BuildContext context, {
    required String title,
    required String message,
    AppStatusTone tone = AppStatusTone.info,
    Duration duration = const Duration(seconds: 3),
    IconData? icon,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        backgroundColor: Colors.transparent,
        padding: EdgeInsets.zero,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        duration: duration,
        content: AppStatusBanner(
          title: title,
          message: message,
          tone: tone,
          icon: icon,
        ),
      ),
    );
  }
}

/// Compact in-place status card (sheet / form). Same look as the toast.
class AppStatusBanner extends StatelessWidget {
  const AppStatusBanner({
    super.key,
    required this.title,
    required this.message,
    this.tone = AppStatusTone.info,
    this.icon,
    this.onDismiss,
  });

  final String title;
  final String message;
  final AppStatusTone tone;
  final IconData? icon;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final palette = _palette(tone);
    final resolvedIcon = icon ?? palette.icon;

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        decoration: BoxDecoration(
          color: palette.bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: palette.border),
          boxShadow: [
            BoxShadow(
              color: palette.accent.withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: palette.accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(resolvedIcon, color: palette.accent, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: palette.title,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    message,
                    style: TextStyle(
                      color: palette.body,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            if (onDismiss != null)
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: onDismiss,
                icon: Icon(Icons.close_rounded, size: 18, color: palette.body),
              ),
          ],
        ),
      ),
    );
  }

  static _TonePalette _palette(AppStatusTone tone) {
    switch (tone) {
      case AppStatusTone.success:
        return const _TonePalette(
          bg: Color(0xFFECFDF5),
          border: Color(0xFFA7F3D0),
          accent: Color(0xFF059669),
          title: Color(0xFF065F46),
          body: Color(0xFF047857),
          icon: Icons.check_circle_rounded,
        );
      case AppStatusTone.info:
        return const _TonePalette(
          bg: Color(0xFFEFF6FF),
          border: Color(0xFFBFDBFE),
          accent: Color(0xFF2563EB),
          title: Color(0xFF1E3A8A),
          body: Color(0xFF1D4ED8),
          icon: Icons.info_rounded,
        );
      case AppStatusTone.warning:
        return const _TonePalette(
          bg: Color(0xFFFFFBEB),
          border: Color(0xFFFDE68A),
          accent: Color(0xFFD97706),
          title: Color(0xFF92400E),
          body: Color(0xFFB45309),
          icon: Icons.warning_amber_rounded,
        );
      case AppStatusTone.error:
        return const _TonePalette(
          bg: Color(0xFFFEF2F2),
          border: Color(0xFFFECACA),
          accent: Color(0xFFDC2626),
          title: Color(0xFF991B1B),
          body: Color(0xFFB91C1C),
          icon: Icons.error_outline_rounded,
        );
    }
  }
}

class _TonePalette {
  const _TonePalette({
    required this.bg,
    required this.border,
    required this.accent,
    required this.title,
    required this.body,
    required this.icon,
  });

  final Color bg;
  final Color border;
  final Color accent;
  final Color title;
  final Color body;
  final IconData icon;
}
