import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../settings/app_settings.dart';

/// LLM provider + API key (stored in [AppSettings.aiApiKey] for now).
class SettingsAiGenerateScreen extends StatefulWidget {
  const SettingsAiGenerateScreen({super.key});

  @override
  State<SettingsAiGenerateScreen> createState() => _SettingsAiGenerateScreenState();
}

class _SettingsAiGenerateScreenState extends State<SettingsAiGenerateScreen> {
  late final TextEditingController _key;
  String _provider = 'openai';
  bool _seeded = false;

  @override
  void initState() {
    super.initState();
    _key = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_seeded) {
      _seeded = true;
      _key.text = AppSettingsScope.of(context).aiApiKey;
    }
  }

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final app = AppSettingsScope.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.aiGenerateNavTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(s.llmProviderLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'openai', label: Text('OpenAI')),
              ButtonSegment(value: 'anthropic', label: Text('Anthropic')),
              ButtonSegment(value: 'local', label: Text('Local')),
            ],
            selected: {_provider},
            onSelectionChanged: (v) => setState(() => _provider = v.first),
          ),
          const SizedBox(height: 20),
          Text(s.apiKeyLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          TextField(
            controller: _key,
            obscureText: true,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () async {
              await app.setAppPreferences(
                mode: app.themeMode,
                updates: app.autoInstallUpdates,
                apiKey: _key.text,
                sms2fa: app.sms2faEnabled,
              );
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.saveSettings)));
            },
            child: Text(s.saveSettings),
          ),
        ],
      ),
    );
  }
}
