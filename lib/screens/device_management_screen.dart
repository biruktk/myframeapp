import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/pairing_nav_result.dart';
import '../navigation/pairing_flow_nav.dart';
import '../services/device_store.dart';
import '../services/usage_metrics_store.dart';
import '../services/app_release_guard.dart';
import 'device_discovery_screen.dart';
import 'frame_profile_setup_screen.dart';

/// `openDeviceManagement` in the HTML mockup — device details + path to repair pairing.
class DeviceManagementScreen extends StatefulWidget {
  const DeviceManagementScreen({super.key});

  @override
  State<DeviceManagementScreen> createState() => _DeviceManagementScreenState();
}

class _DeviceManagementScreenState extends State<DeviceManagementScreen> {
  UsageMetrics? _metrics;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await DeviceStore.instance.load();
    final m = await UsageMetricsStore.instance.load();
    if (mounted) {
      setState(() => _metrics = m);
    }
  }

  String _since(DateTime? dt) {
    if (dt == null) return '--';
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final p = DeviceStore.instance.cached;
    final cs = Theme.of(context).colorScheme;
    final photoCount = _metrics?.photosSentCount ?? 0;
    final uptime = _metrics?.firstSeenAt == null ? '--' : '${DateTime.now().difference(_metrics!.firstSeenAt!).inDays}d';
    final lastPhoto = _since(_metrics?.lastPhotoAt);
    return Scaffold(
      appBar: AppBar(title: Text(s.deviceManagementTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(s.deviceManagementIntro, style: TextStyle(color: cs.onSurfaceVariant, height: 1.45)),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  _Metric(label: s.photos, value: '$photoCount'),
                  _Metric(label: s.uptime, value: uptime),
                  _Metric(label: 'Last photo', value: lastPhoto),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text('Paired devices', style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: cs.primary.withValues(alpha: 0.12),
                child: Icon(Icons.home, color: cs.primary),
              ),
              title: Text(p == null ? s.notPaired : p.listDisplayTitle(s), style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(
                p == null
                    ? s.noLiveDeviceData
                    : p.isWifiProvisioned
                        ? s.wifiLinkedStatus(p.wifiSsid!)
                        : (p.apiUrl ?? s.noLiveDeviceData),
              ),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: () async {
              final result = await SafeNav.push<PairingNavResult>(
                context,
                MaterialPageRoute<PairingNavResult>(
                  builder: (_) => const DeviceDiscoveryScreen(),
                ),
              );
              if (result?.success == true && mounted) await _load();
              PairingFlowNav.onComplete(result);
            },
            icon: const Icon(Icons.bluetooth_searching),
            label: Text(s.repairPairing),
          ),
          const SizedBox(height: 14),
          Text('Device details', style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.edit_outlined, color: cs.primary),
                  title: Text(s.frameNameLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(p == null ? '—' : p.listDisplayTitle(s)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: p == null
                      ? null
                      : () async {
                          await Navigator.push<bool>(
                            context,
                            MaterialPageRoute<bool>(
                              builder: (_) => const FrameProfileSetupScreen(),
                            ),
                          );
                          if (mounted) await _load();
                        },
                ),
                ListTile(
                  leading: Icon(Icons.crop_rotate, color: cs.primary),
                  title: Text(s.frameOrientationLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(p?.frameOrientation ?? '—'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: p == null
                      ? null
                      : () async {
                          await Navigator.push<bool>(
                            context,
                            MaterialPageRoute<bool>(
                              builder: (_) => const FrameProfileSetupScreen(),
                            ),
                          );
                          if (mounted) await _load();
                        },
                ),

              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
