import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../widgets/ai_content_notice.dart';
import '../settings/app_settings.dart';

/// OpenAI + Gemini API keys for Send → AI Generate.
class SettingsAiGenerateScreen extends StatefulWidget {
  const SettingsAiGenerateScreen({super.key, this.autoReturnAfterSave = false});

  /// When true, pops with `true` after a successful save (Send → AI flow).
  final bool autoReturnAfterSave;

  @override
  State<SettingsAiGenerateScreen> createState() => _SettingsAiGenerateScreenState();
}

class _SettingsAiGenerateScreenState extends State<SettingsAiGenerateScreen> {
  late final TextEditingController _openAiKey;
  late final TextEditingController _geminiKey;
  String _provider = 'openai';
  bool _seeded = false;

  @override
  void initState() {
    super.initState();
    _openAiKey = TextEditingController();
    _geminiKey = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_seeded) {
      _seeded = true;
      final app = AppSettingsScope.of(context);
      _provider = app.aiImageProvider;
      _openAiKey.text = app.aiOpenAiApiKey;
      _geminiKey.text = app.aiGeminiApiKey;
    }
  }

  @override
  void dispose() {
    _openAiKey.dispose();
    _geminiKey.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final app = AppSettingsScope.of(context);
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(s.aiGenerateNavTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            s.aiImageSettingsIntro,
            style: TextStyle(color: cs.onSurfaceVariant, height: 1.4),
          ),
          const SizedBox(height: 12),
          const AiContentNotice(),
          const SizedBox(height: 16),
          Text(s.aiImageDefaultProviderLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'openai', label: Text(s.aiProviderOpenAi)),
              ButtonSegment(value: 'gemini', label: Text(s.aiProviderGemini)),
            ],
            selected: {_provider},
            onSelectionChanged: (v) => setState(() => _provider = v.first),
          ),
          const SizedBox(height: 20),
          Text(s.aiOpenAiKeyLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          TextField(
            controller: _openAiKey,
            obscureText: true,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: s.aiOpenAiKeyHint,
            ),
          ),
          const SizedBox(height: 16),
          Text(s.aiGeminiKeyLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          TextField(
            controller: _geminiKey,
            obscureText: true,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: s.aiGeminiKeyHint,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () async {
              await app.setAiImageSettings(
                provider: _provider,
                openAiKey: _openAiKey.text,
                geminiKey: _geminiKey.text,
              );
              if (!context.mounted) return;
              if (widget.autoReturnAfterSave && app.activeAiImageApiKey.isNotEmpty) {
                Navigator.pop(context, true);
                return;
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(s.aiImageKeysSaved)),
              );
            },
            child: Text(s.saveSettings),
          ),
        ],
      ),
    );
  }
}
