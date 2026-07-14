import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../widgets/firmware_update_panel.dart';

class SettingsFirmwareScreen extends StatelessWidget {
  const SettingsFirmwareScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.firmwareUpdateTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          FirmwareUpdatePanel(),
        ],
      ),
    );
  }
}
