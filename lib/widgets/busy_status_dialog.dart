import 'package:flutter/material.dart';

/// Non-dismissible status dialog while a long action runs (e.g. album delete).
class BusyStatusDialog {
  BusyStatusDialog._();

  static Future<T> run<T>(
    BuildContext context, {
    required String message,
    required Future<T> Function() action,
  }) async {
    if (!context.mounted) return await action();

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return PopScope(
          canPop: false,
          child: AlertDialog(
            contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
            content: Row(
              children: [
                SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    try {
      return await action();
    } finally {
      if (context.mounted) {
        final nav = Navigator.of(context, rootNavigator: true);
        if (nav.canPop()) nav.pop();
      }
    }
  }
}
