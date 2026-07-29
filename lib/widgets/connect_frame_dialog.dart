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
