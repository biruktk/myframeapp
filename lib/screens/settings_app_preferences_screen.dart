import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../settings/app_settings.dart';
import 'settings_appearance_screen.dart';

class SettingsAppPreferencesScreen extends StatefulWidget {
  const SettingsAppPreferencesScreen({super.key});

  @override
  State<SettingsAppPreferencesScreen> createState() => _SettingsAppPreferencesScreenState();
}

class _SettingsAppPreferencesScreenState extends State<SettingsAppPreferencesScreen> {
  late ThemeMode _mode;
  var _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    final a = AppSettingsScope.of(context);
    _mode = a.themeMode;
    _loaded = true;
  }

  Future<void> _persistTheme() async {
    final app = AppSettingsScope.of(context);
    await app.setAppPreferences(mode: _mode, updates: app.automaticFrameFirmwareUpdates);
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
          const SizedBox(height: 12),
          Text(s.prefsSectionTheme, style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(s.prefsAppThemeLabel, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<ThemeMode>(
                    value: _mode,
                    items: [
                      DropdownMenuItem(value: ThemeMode.light, child: Text(s.themeModeLabel(ThemeMode.light))),
                      DropdownMenuItem(value: ThemeMode.dark, child: Text(s.themeModeLabel(ThemeMode.dark))),
                      DropdownMenuItem(value: ThemeMode.system, child: Text(s.themeModeLabel(ThemeMode.system))),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _mode = v);
                      _persistTheme();
                    },
                  ),
                ],
              ),
            ),
          ),
          TextButton.icon(
            onPressed: () {
              Navigator.push<void>(
                context,
                MaterialPageRoute<void>(builder: (_) => const SettingsAppearanceScreen()),
              );
            },
            icon: const Icon(Icons.palette_outlined, size: 18),
            label: Text(s.appearanceTitle),
          ),
        ],
      ),
    );
  }
}
