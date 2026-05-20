import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../settings/app_settings.dart';

class SettingsLanguageScreen extends StatelessWidget {
  const SettingsLanguageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final app = AppSettingsScope.of(context);
    final options = <(String?, String)>[
      (null, s.languageSystem),
      ('en', s.languageEnglish),
      ('zh', s.languageChinese),
      ('es', s.languageSpanish),
      ('fr', s.languageFrench),
      ('de', s.languageGerman),
      ('ja', s.languageJapanese),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(s.language)),
      body: ListView(
        children: [
          for (final o in options)
            RadioListTile<String?>(
              value: o.$1,
              groupValue: app.languageCode,
              title: Text(o.$2),
              onChanged: (v) {
                app.setLanguageCode(v);
              },
            ),
        ],
      ),
    );
  }
}
