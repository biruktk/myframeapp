import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../settings/app_settings.dart';
import '../theme/app_theme.dart';

class SettingsAppearanceScreen extends StatefulWidget {
  const SettingsAppearanceScreen({super.key});

  @override
  State<SettingsAppearanceScreen> createState() => _SettingsAppearanceScreenState();
}

class _SettingsAppearanceScreenState extends State<SettingsAppearanceScreen> {
  late ThemeMode _mode;
  late AppAccent _accent;
  var _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    final app = AppSettingsScope.of(context);
    _mode = app.themeMode;
    _accent = app.accent;
    _loaded = true;
  }

  Future<void> _applyThemeMode(ThemeMode mode) async {
    setState(() => _mode = mode);
    await AppSettingsScope.of(context).setThemeMode(mode);
  }

  Future<void> _save() async {
    final app = AppSettingsScope.of(context);
    await app.setThemeMode(_mode);
    await app.setAccent(_accent);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppStrings.of(context).saveLabel)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.appearanceTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(s.themeModeSection, style: const TextStyle(fontWeight: FontWeight.w700)),
          RadioListTile<ThemeMode>(
            value: ThemeMode.light,
            groupValue: _mode,
            onChanged: (v) => _applyThemeMode(v!),
            title: Text(s.themeLight),
          ),
          RadioListTile<ThemeMode>(
            value: ThemeMode.dark,
            groupValue: _mode,
            onChanged: (v) => _applyThemeMode(v!),
            title: Text(s.themeDark),
          ),
          RadioListTile<ThemeMode>(
            value: ThemeMode.system,
            groupValue: _mode,
            onChanged: (v) => _applyThemeMode(v!),
            title: Text(s.themeSystem),
            subtitle: Text(
              s.themeSystemSubtitle,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
          const Divider(),
          Text(s.themeAccentSection, style: const TextStyle(fontWeight: FontWeight.w700)),
          RadioListTile<AppAccent>(
            value: AppAccent.red,
            groupValue: _accent,
            onChanged: (v) => setState(() => _accent = v!),
            title: Text(s.accentRed),
          ),
          RadioListTile<AppAccent>(
            value: AppAccent.green,
            groupValue: _accent,
            onChanged: (v) => setState(() => _accent = v!),
            title: Text(s.accentGreen),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: Text(s.saveLabel),
          ),
        ],
      ),
    );
  }
}
