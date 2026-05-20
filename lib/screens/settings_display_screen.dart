import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../settings/app_settings.dart';

/// Display-oriented settings moved out of Device management (refresh interval + comfort duplicates App prefs comfort — single place here).
class SettingsDisplayScreen extends StatefulWidget {
  const SettingsDisplayScreen({super.key});

  @override
  State<SettingsDisplayScreen> createState() => _SettingsDisplayScreenState();
}

class _SettingsDisplayScreenState extends State<SettingsDisplayScreen> {
  int _refreshMinutes = 30;

  Future<void> _saveComfort(AppSettings app) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.of(context).saveLabel)));
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final app = AppSettingsScope.of(context);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(s.displaySettingsScreenTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(s.displaySettingsIntro, style: TextStyle(color: cs.onSurfaceVariant, height: 1.45)),
          const SizedBox(height: 16),
          Card(
            child: SwitchListTile.adaptive(
              value: app.comfortMode,
              onChanged: (v) async {
                await app.setComfortMode(v);
                if (mounted) setState(() {});
                await _saveComfort(app);
              },
              title: Text(s.comfortMode),
              subtitle: Text(s.comfortModeSubtitle),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListTile(
                  leading: const Icon(Icons.refresh),
                  title: Text(s.displayAutoRefreshTitle),
                  subtitle: Text(s.displayAutoRefreshSubtitle(_refreshMinutes)),
                ),
                Slider(
                  min: 5,
                  max: 120,
                  divisions: 23,
                  value: _refreshMinutes.toDouble(),
                  onChanged: (v) => setState(() => _refreshMinutes = v.round()),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            s.displayAutoRefreshFootnote,
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, height: 1.35),
          ),
        ],
      ),
    );
  }
}
