import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../settings/app_settings.dart';
import '../theme/app_theme.dart';

class SettingsAppPreferencesScreen extends StatefulWidget {
  const SettingsAppPreferencesScreen({super.key});

  @override
  State<SettingsAppPreferencesScreen> createState() => _SettingsAppPreferencesScreenState();
}

class _SettingsAppPreferencesScreenState extends State<SettingsAppPreferencesScreen> {
  late ThemeMode _mode;
  late AppAccent _accent;
  var _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    final a = AppSettingsScope.of(context);
    _mode = a.themeMode;
    _accent = a.accent;
    _loaded = true;
  }

  Future<void> _applyThemeMode(ThemeMode mode) async {
    setState(() => _mode = mode);
    await AppSettingsScope.of(context).setThemeMode(mode);
  }

  Future<void> _saveAppearance() async {
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
    final cs = Theme.of(context).colorScheme;
    final app = AppSettingsScope.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.appPreferences)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: SwitchListTile.adaptive(
              value: app.comfortMode,
              onChanged: (v) async {
                await app.setComfortMode(v);
                if (mounted) setState(() {});
              },
              title: Text(s.comfortMode),
              subtitle: Text(s.comfortModeSubtitle),
            ),
          ),
          const SizedBox(height: 20),
          Text(s.themeModeSection, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                RadioListTile<ThemeMode>(
                  value: ThemeMode.light,
                  groupValue: _mode,
                  onChanged: (v) => _applyThemeMode(v!),
                  title: Text(s.themeLight),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                RadioListTile<ThemeMode>(
                  value: ThemeMode.dark,
                  groupValue: _mode,
                  onChanged: (v) => _applyThemeMode(v!),
                  title: Text(s.themeDark),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                RadioListTile<ThemeMode>(
                  value: ThemeMode.system,
                  groupValue: _mode,
                  onChanged: (v) => _applyThemeMode(v!),
                  title: Text(s.themeSystem),
                  subtitle: Text(
                    s.themeSystemSubtitle,
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(s.themeAccentSection, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                RadioListTile<AppAccent>(
                  value: AppAccent.red,
                  groupValue: _accent,
                  onChanged: (v) => setState(() => _accent = v!),
                  title: Text(s.accentRed),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                RadioListTile<AppAccent>(
                  value: AppAccent.green,
                  groupValue: _accent,
                  onChanged: (v) => setState(() => _accent = v!),
                  title: Text(s.accentGreen),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _saveAppearance,
            icon: const Icon(Icons.save),
            label: Text(s.saveLabel),
          ),
        ],
      ),
    );
  }
}
