import 'dart:async';

import 'package:flutter/material.dart';
import '../utils/platform_share.dart';

import '../config/vps_defaults.dart';
import '../l10n/app_strings.dart';
import '../services/ble_frame_device_transport.dart';
import '../services/ble_display_name.dart';
import '../models/pairing_nav_result.dart';
import '../services/device_store.dart';
import '../services/frame_forget_service.dart';
import '../services/app_release_guard.dart';
import '../navigation/pairing_flow_nav.dart';
import '../services/device_transport.dart' show FrameConnectionState;
import '../services/family_group_store.dart';
import '../services/frame_manual_config_service.dart';
import '../services/frame_mac_util.dart';
import '../services/usage_metrics_store.dart';
import '../settings/app_settings.dart';
import 'device_discovery_screen.dart';
import 'frame_detail_screen.dart';

/// My Frames — paired list, add (+), share, frame detail (spec redesign).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey _addKey = GlobalKey();
  UsageMetrics? _metrics;
  OverlayEntry? _coachEntry;
  bool? _activeFrameServerOnline;
  bool _checkingFrameStatus = false;

  @override
  void initState() {
    super.initState();
    DeviceStore.instance.revision.addListener(_onDeviceStoreRevision);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    DeviceStore.instance.revision.removeListener(_onDeviceStoreRevision);
    _removeCoach();
    super.dispose();
  }

  void _onDeviceStoreRevision() {
    if (!mounted) return;
    unawaited(_load());
  }

  void _removeCoach() {
    _coachEntry?.remove();
    _coachEntry = null;
  }

  Future<void> _load() async {
    await DeviceStore.instance.load();
    if (!mounted) return;
    final app = AppSettingsScope.of(context);
    await FamilyGroupStore.instance.ensureLoaded(ownerDisplayName: () {
      final name = app.profileName.trim();
      if (name.isNotEmpty) return name;
      final mail = app.accountEmail.trim();
      if (mail.isNotEmpty) return mail.split('@').first;
      return 'You';
    });
    await UsageMetricsStore.instance.ensureInitialized();
    final metrics = await UsageMetricsStore.instance.load();
    if (!mounted) return;
    setState(() => _metrics = metrics);
    await _refreshActiveFrameStatus();
    _maybeShowCoachmark(app);
  }

  Future<void> _refreshActiveFrameStatus() async {
    final active = DeviceStore.instance.cached;
    final mac = DeviceStore.instance.pairedFrameMac ??
        (active != null
            ? FrameMacUtil.macFromBleName(active.bleNamePrefix ?? '') ??
                FrameMacUtil.normalizeSlug(active.deviceId)
            : null);
    if (mac == null || mac.length != 12) {
      if (mounted) setState(() => _activeFrameServerOnline = null);
      return;
    }
    setState(() => _checkingFrameStatus = true);
    try {
      final online = await FrameManualConfigService.instance
          .checkFrameOnServer(mac);
      if (mounted) setState(() => _activeFrameServerOnline = online);
    } catch (_) {
      if (mounted) setState(() => _activeFrameServerOnline = false);
    } finally {
      if (mounted) setState(() => _checkingFrameStatus = false);
    }
  }

  void _maybeShowCoachmark(AppSettings app) {
    if (!app.pendingHomeAddFrameCoachmark) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = _addKey.currentContext?.findRenderObject() as RenderBox?;
      if (box == null) return;
      final target = box.localToGlobal(Offset.zero);
      final s = AppStrings.of(context);
      final cs = Theme.of(context).colorScheme;
      _coachEntry?.remove();
      _coachEntry = OverlayEntry(
        builder: (ctx) => Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () async {
                  await app.clearHomeAddFrameCoachmark();
                  _removeCoach();
                },
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              top: target.dy + box.size.height + 6,
              child: Material(
                elevation: 10,
                borderRadius: BorderRadius.circular(14),
                color: cs.surface,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(s.coachAddFrameTitle, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      const SizedBox(height: 6),
                      Text(s.coachAddFrameBody, style: TextStyle(color: cs.onSurfaceVariant, height: 1.35)),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton(
                          onPressed: () async {
                            await app.clearHomeAddFrameCoachmark();
                            _removeCoach();
                          },
                          child: Text(s.coachGotIt),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
      Overlay.of(context).insert(_coachEntry!);
    });
  }

  Future<void> _shareInvite(AppStrings s) async {
    if (!mounted) return;
    final app = AppSettingsScope.of(context);
    await FamilyGroupStore.instance.ensureLoaded(ownerDisplayName: () {
      final name = app.profileName.trim();
      if (name.isNotEmpty) return name;
      final mail = app.accountEmail.trim();
      if (mail.isNotEmpty) return mail.split('@').first;
      return 'You';
    });
    if (!mounted) return;
    final g = FamilyGroupStore.instance;
    final url =
        'https://${VpsDefaults.hostnameInk}/join?code=${Uri.encodeComponent(g.inviteCode)}';
    await platformShareText(
      context,
      text: s.familyInviteShareBody(g.familyName, g.inviteCode, url),
      subject: '${s.inviteFamily} · ${g.familyName}',
    );
  }

  bool _frameLikelyOnline(PairedFrame f) {
    final active = DeviceStore.instance.cached;
    if (BleFrameDeviceTransport.instance.connectionUi.value == FrameConnectionState.connected &&
        active != null &&
        active.deviceId.trim() == f.deviceId.trim()) {
      return true;
    }
    return f.isWifiProvisioned || f.hasApiUrl;
  }

  Future<void> _confirmRemoveFrame(AppStrings s, PairedFrame f) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.removePairingTitle),
        content: Text(s.removePairingBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(s.remove)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await FrameForgetService.instance.forgetFrame(f.deviceId);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.myFramesTitle, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            Text(s.myFramesSubtitle, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, fontWeight: FontWeight.w400)),
          ],
        ),
        actions: [
          IconButton(
            key: _addKey,
            tooltip: s.pairBluetoothFrame,
            icon: Icon(Icons.add_circle_outline, color: cs.primary, size: 28),
            onPressed: () async {
              await AppSettingsScope.of(context).clearHomeAddFrameCoachmark();
              _removeCoach();
              final result = await SafeNav.push<PairingNavResult>(
                context,
                MaterialPageRoute<PairingNavResult>(
                  builder: (_) => const DeviceDiscoveryScreen(),
                ),
              );
              await _load();
              PairingFlowNav.onComplete(result);
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListenableBuilder(
        listenable: BleFrameDeviceTransport.instance.connectionUi,
        builder: (context, _) {
          final frames = DeviceStore.instance.pairedFrames;
          final activeId = DeviceStore.instance.cached?.deviceId.trim();
          var onlineC = 0;
          for (final f in frames) {
            if (_frameLikelyOnline(f)) onlineC++;
          }
          final total = frames.length;
          final offlineC = total - onlineC;

          final active = DeviceStore.instance.cached;
          final showOfflineBanner = active != null &&
              _activeFrameServerOnline == false &&
              !_checkingFrameStatus;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            children: [
              if (showOfflineBanner) ...[
                Card(
                  color: Colors.orange.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Colors.orange),
                            SizedBox(width: 8),
                            Text(
                              'Frame offline',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            OutlinedButton(
                              onPressed: _refreshActiveFrameStatus,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    s.framesSummaryResolved(total, onlineC, offlineC),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (frames.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.notPaired, style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Text(s.scanDeviceBody, style: TextStyle(color: cs.onSurfaceVariant, height: 1.4)),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          onPressed: () async {
                            final result = await SafeNav.push<PairingNavResult>(
                              context,
                              MaterialPageRoute<PairingNavResult>(
                                builder: (_) => const DeviceDiscoveryScreen(),
                              ),
                            );
                            await _load();
                            PairingFlowNav.onComplete(result);
                          },
                          icon: const Icon(Icons.bluetooth_searching),
                          label: Text(s.pairBluetoothFrame),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...frames.map((PairedFrame f) {
                  final online = _frameLikelyOnline(f);
                  final isActive = activeId != null && activeId == f.deviceId.trim();
                  final titleText = f.listDisplayTitle(s);
                  final noCustomName = f.frameName == null || f.frameName!.trim().isEmpty;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () async {
                          await DeviceStore.instance.setActiveFrameDeviceId(f.deviceId);
                          if (!mounted) return;
                          await Navigator.push<void>(
                            context,
                            MaterialPageRoute<void>(builder: (_) => const FrameDetailScreen()),
                          );
                          await _load();
                        },
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  width: 56,
                                  height: 56,
                                  color: cs.primary.withValues(alpha: 0.12),
                                  child: Icon(Icons.photo_size_select_actual_outlined, color: cs.primary, size: 32),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            titleText,
                                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (isActive) ...[
                                          const SizedBox(width: 8),
                                          Chip(
                                            visualDensity: VisualDensity.compact,
                                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                                            label: Text(s.activeFrameLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                                          ),
                                        ],
                                      ],
                                    ),
                                    if (noCustomName) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        BleDisplayName.fallbackTitle(f.bleRemoteId ?? f.deviceId),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: cs.onSurfaceVariant,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 6),
                                    Text(
                                      '${s.frameModelDefault} · ${online ? s.statusOnline : s.statusOffline}',
                                      style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                                    ),
                                    if (_metrics?.lastPhotoAt != null) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        s.lastPhotoDynamic(_relative(_metrics!.lastPhotoAt!, s)),
                                        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: s.shareToFamily,
                                    onPressed: () => unawaited(_shareInvite(s)),
                                    icon: Icon(Icons.ios_share_rounded, color: cs.primary, size: 22),
                                  ),
                                  PopupMenuButton<String>(
                                    tooltip: s.remove,
                                    onSelected: (value) {
                                      if (value == 'remove') unawaited(_confirmRemoveFrame(s, f));
                                    },
                                    itemBuilder: (ctx) => [
                                      PopupMenuItem<String>(
                                        value: 'remove',
                                        child: Text(s.remove),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }

  String _relative(DateTime ts, AppStrings s) {
    final d = DateTime.now().difference(ts);
    if (d.inSeconds < 45) return s.justNow;
    if (d.inMinutes < 60) return s.minutesAgo(d.inMinutes);
    if (d.inHours < 48) return s.hoursAgo(d.inHours);
    return s.daysAgo(d.inDays);
  }
}
