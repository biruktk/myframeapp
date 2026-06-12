import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/pairing_nav_result.dart';
import '../navigation/pairing_flow_nav.dart';
import '../screens/device_discovery_screen.dart';
import '../services/device_store.dart';
import 'shell_navigation.dart';

/// Wi‑Fi: uploads use HTTP to the frame/hub after BLE discovery + provisioning.
void showWifiConnectionInfo(BuildContext context) {
  final s = AppStrings.of(context);
  final p = DeviceStore.instance.cached;
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(s.wifiConnectTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              s.wifiConnectBody,
              style: TextStyle(color: Theme.of(ctx).colorScheme.onSurfaceVariant, height: 1.45),
            ),
            if (p != null) ...[
              const SizedBox(height: 12),
              Text('${s.pairedFrameLabel}: ${p.listDisplayTitle(s)}', style: const TextStyle(fontWeight: FontWeight.w600)),
              Text('${s.deviceIdLabel}: ${p.deviceId}', style: TextStyle(fontSize: 13, color: Theme.of(ctx).colorScheme.onSurfaceVariant, fontFamily: 'monospace')),
              if (p.apiUrl != null) Text('${s.pairedUrlLabel}: ${p.apiUrl}'),
            ] else
              Text(s.wifiNotPairedHint, style: TextStyle(color: Theme.of(ctx).colorScheme.error, height: 1.3)),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (context.mounted) ShellNavigation.goToTab(2);
                });
              },
              child: Text(s.openSendWifiCta),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () {
                Navigator.pop(ctx);
                WidgetsBinding.instance.addPostFrameCallback((_) async {
                  if (!context.mounted) return;
                  final result = await Navigator.of(context).push<PairingNavResult>(
                    MaterialPageRoute<PairingNavResult>(
                      builder: (_) => const DeviceDiscoveryScreen(),
                    ),
                  );
                  PairingFlowNav.onComplete(result);
                });
              },
              child: Text(s.scanDeviceTitle),
            ),
          ],
        ),
      );
    },
  );
}

void showBluetoothConnectionInfo(BuildContext context) {
  // Keep Bluetooth action direct to reduce user friction.
  ShellNavigation.goToTab(2);
}
