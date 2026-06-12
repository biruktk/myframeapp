import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../services/slideshow_style.dart';
import '../settings/app_settings.dart';
import 'settings_appearance_screen.dart';

class SettingsAppPreferencesScreen extends StatefulWidget {
  const SettingsAppPreferencesScreen({super.key});

  @override
  State<SettingsAppPreferencesScreen> createState() => _SettingsAppPreferencesScreenState();
}

class _SettingsAppPreferencesScreenState extends State<SettingsAppPreferencesScreen> {
  late ThemeMode _mode;
  late SlideshowStyle _slideshow;
  late bool _updates;
  var _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    final a = AppSettingsScope.of(context);
    _mode = a.themeMode;
    _slideshow = a.defaultSlideshowStyle;
    _updates = a.automaticFrameFirmwareUpdates;
    _loaded = true;
  }

  Future<void> _persistThemeAndUpdates() async {
    final app = AppSettingsScope.of(context);
    await app.setAppPreferences(mode: _mode, updates: _updates);
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
                      _persistThemeAndUpdates();
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
          Text(s.prefsSectionAutomation, style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Card(
            child: _PrefRow(
              icon: Icons.system_update_outlined,
              title: s.prefsSoftwareUpdatesFrame,
              subtitle: s.prefsSoftwareUpdatesFrameSub,
              trailing: Switch.adaptive(
                value: _updates,
                onChanged: (v) {
                  setState(() => _updates = v);
                  _persistThemeAndUpdates();
                },
              ),
            ),
          ),
          if (!app.automaticFrameFirmwareUpdates) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                s.appPrefsOtaDeviceStoppedHint,
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant, height: 1.35),
              ),
            ),
          ],
          const SizedBox(height: 4),
          SwitchListTile.adaptive(
            value: app.comfortMode,
            onChanged: (v) async {
              await app.setComfortMode(v);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(v ? s.comfortModeOn : s.comfortModeOff)),
              );
              setState(() {});
            },
            title: Text(s.comfortMode),
            subtitle: Text(s.comfortModeSubtitle),
          ),
        ],
      ),
    );
  }
}

class _PrefRow extends StatelessWidget {
  const _PrefRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: cs.surfaceContainerHighest,
        child: Icon(icon, size: 20, color: cs.primary),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: trailing,
    );
  }
}
