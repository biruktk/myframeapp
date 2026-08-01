import 'package:flutter/material.dart';

import '../widgets/connect_frame_dialog.dart';
import 'device_store.dart';
import 'frame_api_client.dart';

/// Blocks photo send / upload flows when the target frame is offline.
class FrameOnlineGuard {
  FrameOnlineGuard._();

  static String? macForFrame(PairedFrame f) => DeviceStore.macForPairedFrame(f);

  /// Live status check against the cloud status API.
  /// Tries BLE + STA MAC siblings and prefers the VPS API (not a stale LAN URL).
  static Future<bool> isFrameEffectivelyOnline(PairedFrame frame) async {
    final candidates = DeviceStore.statusMacCandidates(frame);
    if (candidates.isEmpty) return false;
    final client = FrameApiClient();
    for (final mac in candidates) {
      try {
        // Do NOT pass frame.apiUrl first — dead LAN overrides VPS and false-offline.
        final status = await client.fetchFrameStatus(
          mac: mac,
          pairingToken: frame.resolvedPairingToken,
        );
        if (status != null && status.isEffectivelyOnline) return true;
      } catch (_) {}
    }
    return false;
  }

  /// Returns `true` when [frame] (or the active paired frame) is online.
  /// Shows connect / offline dialogs otherwise.
  static Future<bool> ensureOnlineForSend(
    BuildContext context, {
    PairedFrame? frame,
  }) async {
    await DeviceStore.instance.load();
    final paired = frame ?? DeviceStore.instance.cached;
    if (paired == null) {
      if (!context.mounted) return false;
      await showConnectFrameFirstDialog(context);
      return false;
    }

    final online = await isFrameEffectivelyOnline(paired);
    if (online) return true;
    if (!context.mounted) return false;
    await showFrameOfflineSendDialog(context);
    return false;
  }

  /// Before a multi-frame picker: allow if any paired frame is online.
  /// With a single frame, requires that frame to be online.
  static Future<bool> ensureCanStartSendFlow(BuildContext context) async {
    await DeviceStore.instance.load();
    final frames = DeviceStore.instance.pairedFrames;
    if (frames.isEmpty) {
      if (!context.mounted) return false;
      await showConnectFrameFirstDialog(context);
      return false;
    }
    if (frames.length == 1) {
      return ensureOnlineForSend(context, frame: frames.first);
    }
    for (final f in frames) {
      if (await isFrameEffectivelyOnline(f)) return true;
    }
    if (!context.mounted) return false;
    await showFrameOfflineSendDialog(context);
    return false;
  }
}
