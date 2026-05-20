import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_strings.dart';
import '../services/app_local_reset.dart';
import '../services/network_link.dart';
import '../services/device_store.dart';
import '../settings/app_settings.dart';

class SettingsDebugScreen extends StatefulWidget {
  const SettingsDebugScreen({super.key});

  @override
  State<SettingsDebugScreen> createState() => _SettingsDebugScreenState();
}

class _SettingsDebugScreenState extends State<SettingsDebugScreen> {
  bool? _onLink;
  PairedFrame? _paired;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await DeviceStore.instance.load();
    final on = await hasNetworkInterface();
    if (!mounted) return;
    setState(() {
      _paired = DeviceStore.instance.cached;
      _onLink = on;
    });
  }

  String _exportBody(AppStrings s) {
    final buf = StringBuffer();
    buf.writeln('MyFrame debug export');
    buf.writeln('Data link: ${_onLink == true ? s.connected : s.notPaired}');
    buf.writeln('Paired: ${_paired?.deviceId ?? s.notPaired}');
    buf.writeln('API: ${_paired?.apiUrl ?? s.debugNoApi}');
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final app = AppSettingsScope.of(context);
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(s.debugModeTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              leading: CircleAvatar(
                backgroundColor: cs.surfaceContainerHighest,
                child: Icon(Icons.bug_report, color: cs.primary),
              ),
              title: Text(s.debugModeTitle),
              subtitle: Text(s.debugOnlySubtitle),
              trailing: Switch.adaptive(
                value: app.debugModeEnabled,
                onChanged: (v) async {
                  await app.setDebugModeEnabled(v);
                  setState(() {});
                },
              ),
            ),
          ),
          if (app.debugModeEnabled) ...[
            _DebugBlock(
              title: s.debugCardNetwork,
              items: [
                (s.debugLabelWifi, _onLink == null ? s.loadingEllipsis : (_onLink! ? s.connected : s.notPaired)),
                (s.debugLabelServer, _paired?.apiUrl == null || _paired!.apiUrl!.isEmpty ? s.debugNoApi : s.connected),
              ],
            ),
            _DebugBlock(
              title: s.debugCardDevice,
              items: [
                (s.openDeviceInfo, _paired == null ? s.notPaired : _paired!.deviceId),
                (s.premiumTitle, s.notAvailable),
                (s.debugDeviceMemory, s.notAvailable),
              ],
            ),
            _DebugBlock(
              title: s.debugCardLogs,
              items: [
                (s.debugLabelSync, s.notAvailable),
                (s.debugLabelErrors, '0'),
                (s.debugLabelCache, s.notAvailable),
              ],
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () {
                Share.share(_exportBody(s), subject: s.debugModeTitle);
              },
              icon: const Icon(Icons.download),
              label: Text(s.exportLogs),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: cs.error, foregroundColor: cs.onError),
              onPressed: () async {
                final go = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: Text(s.factoryResetTitle),
                    content: Text(s.factoryResetBody),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(c, false), child: Text(s.cancel)),
                      FilledButton(
                        onPressed: () => Navigator.pop(c, true),
                        child: Text(s.confirmErase),
                      ),
                    ],
                  ),
                );
                if (go != true || !context.mounted) return;
                await AppLocalReset.wipeAllLocalData();
                if (!context.mounted) return;
                await AppSettingsScope.of(context).reload();
                await _load();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.factoryResetDone)));
              },
              icon: const Icon(Icons.restart_alt),
              label: Text(s.factoryReset),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: Text(s.refreshAction),
            ),
          ],
        ],
      ),
    );
  }
}

class _DebugBlock extends StatelessWidget {
  const _DebugBlock({required this.title, required this.items});

  final String title;
  final List<(String, String)> items;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            for (final e in items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(e.$1, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                    ),
                    Text(e.$2, style: const TextStyle(fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
