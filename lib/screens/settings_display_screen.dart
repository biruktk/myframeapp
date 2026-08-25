import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../settings/app_settings.dart';

class SettingsDisplayScreen extends StatefulWidget {
  const SettingsDisplayScreen({super.key});

  @override
  State<SettingsDisplayScreen> createState() => _SettingsDisplayScreenState();
}

class _SettingsDisplayScreenState extends State<SettingsDisplayScreen> {
  static const _hours = [6, 12, 24, 48, 72];
  int _currentStepIndex = 0;
  var _showDetails = false;

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
          Card(
            child: ListTile(
              enabled: false,
              leading: Icon(Icons.mic_none_outlined, color: cs.onSurfaceVariant),
              title: Text(s.voiceCommandsTitle),
              subtitle: Text(s.voiceCommandsComingSoon),
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
                  subtitle: Text(s.everyNHours(_hours[_currentStepIndex])),
                ),
                Slider(
                  value: _currentStepIndex.toDouble(),
                  min: 0,
                  max: (_hours.length - 1).toDouble(),
                  divisions: _hours.length - 1,
                  activeColor: Colors.red,
                  onChanged: (v) {
                    setState(() => _currentStepIndex = v.round());
                  },
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => setState(() => _showDetails = !_showDetails),
            child: Text(_showDetails ? s.showLessLabel : s.showAllLabel),
          ),
          if (_showDetails) ...[
            Text(
              s.displaySettingsIntro,
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant, height: 1.4),
            ),
            const SizedBox(height: 8),
            Text(
              s.displayAutoRefreshFootnote,
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, height: 1.35),
            ),
          ],
        ],
      ),
    );
  }
}
