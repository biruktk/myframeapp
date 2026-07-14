import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../services/slideshow_style.dart';
import '../settings/app_settings.dart';
import 'settings_display_screen.dart';
import 'settings_appearance_screen.dart';

class SettingsAppPreferencesScreen extends StatefulWidget {
  const SettingsAppPreferencesScreen({super.key});

  @override
  State<SettingsAppPreferencesScreen> createState() => _SettingsAppPreferencesScreenState();
}

class _SettingsAppPreferencesScreenState extends State<SettingsAppPreferencesScreen> {
  late ThemeMode _mode;
  late SlideshowStyle _slideshow;
  var _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    final a = AppSettingsScope.of(context);
    _mode = a.themeMode;
    _slideshow = a.defaultSlideshowStyle;
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
          const SizedBox(height: 12),
          Text(s.prefsSectionSendFrame, style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(s.prefsDefaultSlideshowLabel, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<SlideshowStyle>(
                    value: _slideshow,
                    items: [
                      DropdownMenuItem(value: SlideshowStyle.fade, child: Text(s.styleFade)),
                      DropdownMenuItem(value: SlideshowStyle.kenBurns, child: Text(s.styleKenBurns)),
                      DropdownMenuItem(value: SlideshowStyle.grid, child: Text(s.styleGrid)),
                      DropdownMenuItem(value: SlideshowStyle.random, child: Text(s.styleRandom)),
                    ],
                    onChanged: (v) async {
                      if (v == null) return;
                      setState(() => _slideshow = v);
                      await app.setDefaultSlideshowStyle(v);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: Icon(Icons.accessibility_new_outlined, color: cs.primary),
            title: Text(s.comfortMode),
            subtitle: Text(s.comfortModeSubtitle),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: () {
              Navigator.push<void>(
                context,
                MaterialPageRoute<void>(builder: (_) => const SettingsDisplayScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}
