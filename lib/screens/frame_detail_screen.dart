import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../services/device_store.dart';
import '../settings/app_settings.dart';
import 'frame_profile_setup_screen.dart';

/// Spec: frame row → Device ID, Orientation, Wi‑Fi SSID, firmware update toggle.
class FrameDetailScreen extends StatefulWidget {
  const FrameDetailScreen({super.key});

  @override
  State<FrameDetailScreen> createState() => _FrameDetailScreenState();
}

class _FrameDetailScreenState extends State<FrameDetailScreen> {
  PairedFrame? _p;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    await DeviceStore.instance.load();
    if (mounted) setState(() => _p = DeviceStore.instance.cached);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final app = AppSettingsScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final p = _p;
    return Scaffold(
      appBar: AppBar(title: Text(p == null ? s.frameDetailTitle : p.listDisplayTitle(s))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (p == null)
            Text(s.notPaired, style: TextStyle(color: cs.onSurfaceVariant))
          else ...[
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.edit_outlined, color: cs.primary),
                    title: Text(s.frameNameLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(p.listDisplayTitle(s)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await Navigator.push<bool>(
                        context,
                        MaterialPageRoute<bool>(builder: (_) => const FrameProfileSetupScreen()),
                      );
                      await _reload();
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.tag, color: cs.primary),
                    title: Text(s.deviceIdLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: SelectableText(p.deviceId, style: const TextStyle(fontFamily: 'monospace')),
                  ),
                  ListTile(
                    leading: Icon(Icons.crop_rotate, color: cs.primary),
                    title: Text(s.frameOrientationLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(p.frameOrientation ?? '—'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await Navigator.push<bool>(
                        context,
                        MaterialPageRoute<bool>(builder: (_) => const FrameProfileSetupScreen()),
                      );
                      await _reload();
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.wifi, color: cs.primary),
                    title: Text(s.wifiSsidLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(p.wifiSsid?.trim().isNotEmpty == true ? p.wifiSsid! : '—'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ListenableBuilder(
              listenable: app,
              builder: (context, _) {
                return Card(
                  child: SwitchListTile.adaptive(
                    value: app.automaticFrameFirmwareUpdates,
                    onChanged: (v) async {
                      await app.setAutomaticFrameFirmwareUpdates(v);
                      if (mounted) setState(() {});
                    },
                    title: Text(s.deviceAutomaticFirmwareTitle),
                    subtitle: Text(s.deviceAutomaticFirmwareSub),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
