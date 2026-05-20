import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import 'device_discovery_screen.dart';

/// Pairing guide: power on -> BLE scan -> Wi-Fi provision.
class PairingGuideScreen extends StatelessWidget {
  const PairingGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(s.pairingGuideTitle)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _Step(n: 1, title: s.pairingStep1Title, text: s.pairingStep1Body, icon: Icons.power_settings_new, cs: cs),
          _Step(n: 2, title: s.scanDeviceTitle, text: s.scanDeviceBody, icon: Icons.bluetooth_searching, cs: cs),
          _Step(n: 3, title: s.pairingStep3Title, text: s.pairingStep3Body, icon: Icons.wifi_tethering, cs: cs),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              Navigator.push<void>(
                context,
                MaterialPageRoute<void>(builder: (_) => const DeviceDiscoveryScreen()),
              );
            },
            icon: const Icon(Icons.bluetooth_searching),
            label: Text(s.scanDeviceTitle),
            style: FilledButton.styleFrom(
              backgroundColor: cs.primary,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.n, required this.title, required this.text, required this.icon, required this.cs});

  final int n;
  final String title;
  final String text;
  final IconData icon;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: cs.primary.withValues(alpha: 0.12),
                foregroundColor: cs.primary,
                child: Text('$n', style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(icon, size: 20, color: cs.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(text, style: TextStyle(color: cs.onSurfaceVariant, height: 1.4)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
