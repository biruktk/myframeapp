import 'dart:ui';
import 'package:flutter/material.dart';
import '../l10n/app_strings.dart';

/// Beautiful success dialog shown after photo upload completes
class UploadSuccessDialog extends StatefulWidget {
  const UploadSuccessDialog({
    super.key,
    required this.frameName,
    this.photoCount = 1,
    this.onClose,
  });

  final String? frameName;
  final int photoCount;
  final VoidCallback? onClose;

  static Future<void> show(
    BuildContext context, {
    String? frameName,
    int photoCount = 1,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => UploadSuccessDialog(
        frameName: frameName,
        photoCount: photoCount,
      ),
    );
  }

  @override
  State<UploadSuccessDialog> createState() => _UploadSuccessDialogState();
}

class _UploadSuccessDialogState extends State<UploadSuccessDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _controller.forward();

    // Auto dismiss after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pop();
        widget.onClose?.call();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 340),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Success checkmark icon with animation
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: Colors.green,
                      size: 56,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Title
                  Text(
                    widget.photoCount > 1
                        ? strings.uploadSuccessMultiTitle(widget.photoCount)
                        : strings.uploadSuccessTitle,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),

                  // Message
                  Text(
                    widget.frameName != null
                        ? strings.uploadSuccessMessageWithFrame(widget.frameName!)
                        : strings.uploadSuccessMessage,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),

                  // E-ink refresh note
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceVariant.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 18,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            strings.uploadEinkRefreshNote,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Close button
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onClose?.call();
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      strings.closeAction,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
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

/// Extension methods for easy string access
extension _UploadSuccessStrings on AppStrings {
  String get uploadSuccessTitle => 'Photo Sent Successfully!';
  
  String uploadSuccessMultiTitle(int count) => '$count Photos Sent Successfully!';
  
  String get uploadSuccessMessage => 
      'Your photo has been sent to your frame.';
  
  String uploadSuccessMessageWithFrame(String frameName) =>
      'Your photo has been sent to "$frameName" and will display shortly.';
  
  String get uploadEinkRefreshNote =>
      'E-ink display may take up to a minute to refresh.';
  
  String get closeAction => 'Done';
}
