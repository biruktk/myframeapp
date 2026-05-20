import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../services/ble_frame_device_transport.dart';
import '../services/device_store.dart';
import 'device_discovery_screen.dart';

class SettingsPairingScreen extends StatefulWidget {
  const SettingsPairingScreen({super.key});

  @override
  State<SettingsPairingScreen> createState() => _SettingsPairingScreenState();
}

class _SettingsPairingScreenState extends State<SettingsPairingScreen> {
  PairedFrame? _paired;
  bool _confirmClear = false;

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

  Future<void> _clearPairing() async {
    if (!_confirmClear) {
      setState(() => _confirmClear = true);
      return;
    }
    await DeviceStore.instance.clear();
    await BleFrameDeviceTransport.instance.releaseSession();
    if (!mounted) return;
    setState(() {
      _paired = null;
      _confirmClear = false;
    });
  }

  Future<void> _repair() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(builder: (_) => const DeviceDiscoveryScreen()),
    );
    if (ok == true) {
      await _load();
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
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _paired == null ? null : _clearPairing,
            icon: const Icon(Icons.link_off),
            label: Text(_confirmClear ? s.removePairingTitle : s.clear),
          ),
          if (_confirmClear) ...[
            const SizedBox(height: 8),
            Text(
              s.removePairingBody,
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}
