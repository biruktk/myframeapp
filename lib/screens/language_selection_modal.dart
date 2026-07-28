import 'package:flutter/material.dart';

import '../settings/app_settings.dart';

class LanguageSelectionModal extends StatefulWidget {
  const LanguageSelectionModal({super.key});

  @override
  State<LanguageSelectionModal> createState() => _LanguageSelectionModalState();
}

class _LanguageSelectionModalState extends State<LanguageSelectionModal> {
  String _selectedCode = 'system';

  static const _red = Color(0xFFE53935);

  final List<_LangItem> _languages = const [
    _LangItem('system', 'System Default (English)', '🌐'),
    _LangItem('zh', '简体中文 (Chinese)', '🇨🇳'),
    _LangItem('en', 'English', '🇺🇸'),
    _LangItem('es', 'Español', '🇪🇸'),
    _LangItem('fr', 'Français', '🇫🇷'),
    _LangItem('de', 'Deutsch', '🇩🇪'),
    _LangItem('ja', '日本語', '🇯🇵'),
  ];

  @override
  Widget build(BuildContext context) {
    final app = AppSettingsScope.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Language / 选择语言',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 4),
          const Text(
            'Choose your preferred language to continue',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _languages.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFEEEEEE)),
              itemBuilder: (context, index) {
                final item = _languages[index];
                final isSelected = _selectedCode == item.code;

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Text(item.flag, style: const TextStyle(fontSize: 22)),
                  title: Text(
                    item.name,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? _red : Colors.black87,
                      fontSize: 15,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle, color: _red, size: 20)
                      : null,
                  onTap: () async {
                    setState(() => _selectedCode = item.code);
                    final code = item.code == 'system' ? null : item.code;
                    await app.setLanguageCode(code);
                    if (context.mounted) Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LangItem {
  final String code;
  final String name;
  final String flag;
  const _LangItem(this.code, this.name, this.flag);
}
