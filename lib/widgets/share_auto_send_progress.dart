import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';

/// Lightweight progress overlay used when the native iOS Share Extension has
/// already chosen the target frame. Instead of re-showing the Flutter
/// destination picker, the host sends straight to the pre-selected frame and
/// this dialog reports progress.
class ShareAutoSendProgress {
  ShareAutoSendProgress(this.context);

  final BuildContext context;
  final ValueNotifier<double> progress = ValueNotifier(0.05);
  final ValueNotifier<String> status = ValueNotifier('');
  final ValueNotifier<bool> done = ValueNotifier(false);

  void update(double frac, String text) {
    progress.value = frac.clamp(0.0, 1.0);
    if (text.trim().isNotEmpty) status.value = text;
  }

  Future<void> show() {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => _ShareAutoSendDialog(controller: this),
    );
  }

  /// Signals the dialog to close; call after the cast completes.
  void dismiss() => done.value = true;
}

class _ShareAutoSendDialog extends StatefulWidget {
  const _ShareAutoSendDialog({required this.controller});

  final ShareAutoSendProgress controller;

  @override
  State<_ShareAutoSendDialog> createState() => _ShareAutoSendDialogState();
}

class _ShareAutoSendDialogState extends State<_ShareAutoSendDialog> {
  @override
  void initState() {
    super.initState();
    widget.controller.done.addListener(_maybeClose);
  }

  @override
  void dispose() {
    widget.controller.done.removeListener(_maybeClose);
    widget.controller.progress.dispose();
    widget.controller.status.dispose();
    widget.controller.done.dispose();
    super.dispose();
  }

  void _maybeClose() {
    if (widget.controller.done.value && mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = AppStrings.of(context);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.photo_camera_back, color: cs.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    s.shareSheetTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ValueListenableBuilder<String>(
              valueListenable: widget.controller.status,
              builder: (context, status, _) => Text(
                status.isEmpty ? s.shareSheetSending : status,
                style: TextStyle(
                  fontSize: 14,
                  color: cs.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ),
            const SizedBox(height: 12),
            ValueListenableBuilder<double>(
              valueListenable: widget.controller.progress,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value.clamp(0.0, 1.0),
                minHeight: 8,
                borderRadius: BorderRadius.circular(99),
                backgroundColor: cs.surfaceContainerHighest,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
