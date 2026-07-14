import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/pairing_nav_result.dart';
import '../navigation/pairing_flow_nav.dart';
import '../services/app_release_guard.dart';
import '../services/device_store.dart';
import 'device_discovery_screen.dart';

class SettingsPairingScreen extends StatefulWidget {
  const SettingsPairingScreen({super.key});

  @override
  State<SettingsPairingScreen> createState() => _SettingsPairingScreenState();
}

class _SettingsPairingScreenState extends State<SettingsPairingScreen> {
  PairedFrame? _paired;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await DeviceStore.instance.load();
    if (!mounted) return;
    setState(() => _paired = DeviceStore.instance.cached);
  }

  Future<void> _repair() async {
    final result = await SafeNav.push<PairingNavResult>(
      context,
      MaterialPageRoute<PairingNavResult>(
        builder: (_) => const DeviceDiscoveryScreen(),
      ),
    );
    if (result?.success == true) {
      await _load();
      PairingFlowNav.onComplete(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(s.framePairing)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: Icon(Icons.bluetooth_connected, color: cs.primary),
              title: Text(
                _paired?.listDisplayTitle(s) ?? s.notPaired,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                _paired == null
                    ? s.scanDeviceBody
                    : (_paired!.isWifiProvisioned
                        ? s.wifiLinkedStatus(_paired!.wifiSsid!)
                        : (_paired!.apiUrl == null ? s.pairingQrHint : _paired!.apiUrl!)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _repair,
            icon: const Icon(Icons.bluetooth_searching),
            label: Text(s.scanDeviceTitle),
          ),
        ],
      ),
    );
  }
}
