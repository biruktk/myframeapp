import 'dart:async';

import 'package:flutter/material.dart';

import '../widgets/connect_frame_dialog.dart';
import 'device_store.dart';
import 'frame_api_client.dart';
import 'frame_recovery_service.dart';

/// Optimistic send / upload gating for the frame.
///
/// Matches the WeChat mini app delivery model: photo upload → VPS wakes the
/// frame via MQTT → frame heartbeats → status flips Online. A stale cached
/// "offline" state must never hard-block photo delivery, so these helpers only
/// block when there is no paired frame at all.
class FrameOnlineGuard {
  FrameOnlineGuard._();

  static String? macForFrame(PairedFrame f) => DeviceStore.macForPairedFrame(f);

  /// Provisional-online window after Wi‑Fi provisioning (mirrors Home tiles).
  static const Duration provisionGrace = Duration(minutes: 15);

  /// Consecutive live-probe misses required to flip a freshly provisioned
  /// frame offline. Suppresses transient false-offline right after BLE drops
  /// post Wi‑Fi setup.
  static const int offlineAfterMisses = 3;

  /// Recent heartbeat window for treating a frame as online even when the
  /// status flag trails (frame pinged MQTT but API cache lags).
  static const Duration lastSeenFreshWindow = Duration(seconds: 120);

  static final Map<String, int> _consecutiveMisses = {};

  static bool _withinProvisionGrace(PairedFrame frame) {
    if (!frame.isWifiProvisioned) return false;
    final at = frame.wifiProvisionedAtMs;
    if (at == null) return false;
    final age = DateTime.now().millisecondsSinceEpoch - at;
    return age >= 0 && age < provisionGrace.inMilliseconds;
  }

  /// True when the frame reported activity recently enough to trust delivery.
  static bool _isFreshlyOnline(FrameStatus s) {
    if (s.isEffectivelyOnline) return true;
    final seen = s.lastSeenMs;
    if (seen == null || seen <= 0) return false;
    final age = DateTime.now().millisecondsSinceEpoch - seen;
    if (age >= lastSeenFreshWindow.inMilliseconds) return false;
    // Explicit "offline" status wins; anything else that heartbeated within the
    // window (e.g. lagging API cache) is treated as online.
    return s.status != 'offline';
  }

  /// Live status check against the cloud status API.
  /// Tries BLE + STA MAC siblings and prefers the VPS API (not a stale LAN URL).
  ///
  /// During the [provisionGrace] window a freshly provisioned frame stays
  /// online until [offlineAfterMisses] consecutive live probes miss.
  static Future<bool> isFrameEffectivelyOnline(PairedFrame frame) async {
    final candidates = DeviceStore.statusMacCandidates(frame);
    final client = FrameApiClient();
    var hits = 0;
    try {
      for (final mac in candidates) {
        try {
          // Do NOT pass frame.apiUrl first — dead LAN overrides VPS and false-offline.
          final status = await client.fetchFrameStatus(
            mac: mac,
            pairingToken: frame.resolvedPairingToken,
          );
          if (status != null) {
            if (_isFreshlyOnline(status)) {
              hits++;
              _consecutiveMisses[mac] = 0;
            } else {
              _consecutiveMisses[mac] = (_consecutiveMisses[mac] ?? 0) + 1;
            }
          }
        } catch (_) {}
      }
    } finally {
      client.close();
    }
    if (hits > 0) return true;
    if (_withinProvisionGrace(frame)) {
      var worst = 0;
      for (final mac in candidates) {
        final v = _consecutiveMisses[mac] ?? 0;
        if (v > worst) worst = v;
      }
      return worst < offlineAfterMisses;
    }
    return false;
  }

  /// Returns `true` when [frame] (or the active paired frame) exists so the
  /// send flow can proceed. Never blocks photo delivery on cached offline
  /// state — the send pipeline wakes the frame via MQTT instead.
  /// Shows a connect-first dialog only when no frame is paired at all.
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

    // Fire-and-forget: refresh status cache + wake MQTT session while the
    // user picks photos / edits. Delivery is attempted regardless.
    unawaited(_probeAndWake(paired));
    return true;
  }

  /// Before a send flow: allow whenever at least one frame is paired.
  /// With zero frames, prompts to connect a frame first.
  static Future<bool> ensureCanStartSendFlow(BuildContext context) async {
    await DeviceStore.instance.load();
    final frames = DeviceStore.instance.pairedFrames;
    if (frames.isEmpty) {
      if (!context.mounted) return false;
      await showConnectFrameFirstDialog(context);
      return false;
    }
    final active = frames.length == 1
        ? frames.first
        : (DeviceStore.instance.cached ?? frames.first);
    unawaited(_probeAndWake(active));
    return true;
  }

  static Future<void> _probeAndWake(PairedFrame paired) async {
    await _wakeFrame(paired);
    await isFrameEffectivelyOnline(paired);
  }

  static Future<void> _wakeFrame(PairedFrame paired) async {
    try {
      await FrameRecoveryService.instance.wakeFrameMqtt(paired);
    } catch (_) {
      // Wake is best-effort; the VPS also wakes the frame via MQTT publish.
    }
  }
}
