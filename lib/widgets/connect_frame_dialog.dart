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
