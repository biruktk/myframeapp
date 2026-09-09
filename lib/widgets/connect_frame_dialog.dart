import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';

Future<void> showConnectFrameFirstDialog(BuildContext context) {
  final s = AppStrings.of(context);
  return showDialog<void>(
    context: context,
    builder: (c) => AlertDialog(
      content: Text(s.connectFrameFirst),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: Text(s.cancel)),
        FilledButton(onPressed: () => Navigator.pop(c), child: Text(s.gotItLabel)),
      ],
    ),
  );
}

/// Shown when the user tries to send photos while the frame is offline.
Future<void> showFrameOfflineSendDialog(BuildContext context) {
  final s = AppStrings.of(context);
  return showDialog<void>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(s.frameOfflineReconnectTitle),
      content: Text(s.frameOfflineSendBlockedBody),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(c),
          child: Text(s.gotItLabel),
        ),
      ],
    ),
  );
}

/// Shown when the user tries to send to a frame that is currently in sleep
/// mode (powered down its radio for battery saving). Distinct from offline —
/// sending now would time out / get dropped, so we pause delivery instead.
Future<void> showFrameAsleepSendDialog(BuildContext context) {
  final s = AppStrings.of(context);
  return showDialog<void>(
    context: context,
    builder: (c) => AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.bedtime, color: Color(0xFF7B1FA2)),
          const SizedBox(width: 8),
          Expanded(child: Text(s.frameSleepModeLabel)),
        ],
      ),
      content: Text(s.frameSleepSendBlockedBody),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(c),
          child: Text(s.gotItLabel),
        ),
      ],
    ),
  );
}
