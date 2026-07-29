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
import '../services/frame_api_client.dart';
import '../services/frame_mac_util.dart';
import '../services/usage_metrics_store.dart';
import '../settings/app_settings.dart';
import 'device_discovery_screen.dart';
import 'device_details_screen.dart';

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
  bool _checkingFrameStatus = false;
  Timer? _pollTimer;
  Map<String, FrameStatus> _frameStatuses = {};
  final FrameApiClient _apiClient = FrameApiClient();

  @override
  void initState() {
    super.initState();
    DeviceStore.instance.revision.addListener(_onDeviceStoreRevision);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
      _startPolling();
    });
  }

  @override
  void dispose() {
    DeviceStore.instance.revision.removeListener(_onDeviceStoreRevision);
    _removeCoach();
    _pollTimer?.cancel();
    _apiClient.close();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _refreshAllFrameStatuses();
    });
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
    await _refreshAllFrameStatuses();
    _maybeShowCoachmark(app);
  }

  Future<void> _refreshAllFrameStatuses() async {
    final frames = DeviceStore.instance.pairedFrames;
    if (frames.isEmpty) {
      if (mounted) setState(() {
        _frameStatuses = {};
      });
      return;
    }
    setState(() => _checkingFrameStatus = true);
    final updated = Map<String, FrameStatus>.from(_frameStatuses);
    for (final f in frames) {
      final mac = _macForFrame(f);
      if (mac == null) continue;
      try {
        final status = await _apiClient.fetchFrameStatus(mac: mac);
        if (status != null) {
          updated[f.deviceId] = status;
        }
      } catch (_) {}
    }
    if (mounted) setState(() {
      _frameStatuses = updated;
      _checkingFrameStatus = false;
    });
  }

  String? _macForFrame(PairedFrame f) {
    return DeviceStore.instance.pairedFrameMac ??
        FrameMacUtil.macFromBleName(f.bleNamePrefix ?? '') ??
        FrameMacUtil.normalizeSlug(f.deviceId);
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

  void _showOfflineDialog() {
    final s = AppStrings.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.frameOfflineReconnectTitle),
        content: Text(s.frameOfflineReconnectBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(s.gotItLabel),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.myFramesTitle, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: cs.onSurface)),
            const SizedBox(height: 2),
            Text(s.myFramesSubtitle, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
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
          bool isOnline(PairedFrame f) {
            final st = _frameStatuses[f.deviceId];
            if (st != null) return st.online;
            return _frameLikelyOnline(f);
          }

          final total = frames.length;
          var onlineC = 0;
          for (final f in frames) {
            if (isOnline(f)) onlineC++;
          }
          final offlineC = total - onlineC;

          final active = DeviceStore.instance.cached;
          final showOfflineBanner = active != null &&
              _frameStatuses.isNotEmpty &&
              onlineC == 0 &&
              !_checkingFrameStatus;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            children: [
              if (showOfflineBanner) ...[
                GestureDetector(
                  onTap: _showOfflineDialog,
                  child: Card(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.orange.shade900.withOpacity(0.35)
                        : Colors.orange.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              s.frameOfflineLabel,
                              style: TextStyle(fontWeight: FontWeight.w800, color: cs.onSurface),
                            ),
                          ),
                          Icon(Icons.chevron_right, color: Colors.orange.shade300),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(
                        Theme.of(context).brightness == Brightness.dark ? 0.28 : 0.04,
                      ),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      total == 1 ? '1 ${s.statusFrame}' : '$total ${s.statusFrames}',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: cs.onSurface),
                    ),
                    Row(
                      children: [
                        Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF4CAF50), shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Text('$onlineC ${s.statusOnline}', style: TextStyle(fontSize: 13, color: cs.onSurface)),
                        const SizedBox(width: 12),
                        Text('·', style: TextStyle(color: cs.outline)),
                        const SizedBox(width: 12),
                        Container(width: 8, height: 8, decoration: BoxDecoration(color: cs.onSurfaceVariant, shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Text('$offlineC ${s.statusOffline}', style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                      ],
                    ),
                  ],
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
                  final online = isOnline(f);
                  final isActive = activeId != null && activeId == f.deviceId.trim();
                  final titleText = f.listDisplayTitle(s);
                  final noCustomName = f.frameName == null || f.frameName!.trim().isEmpty;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: cs.outlineVariant),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () async {
                          await DeviceStore.instance.setActiveFrameDeviceId(f.deviceId);
                          if (!mounted) return;
                          await Navigator.push<void>(
                            context,
                            MaterialPageRoute<void>(builder: (_) => const DeviceDetailsScreen()),
                          );
                          await _load();
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: cs.primary.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(Icons.crop_original, color: cs.primary, size: 28),
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
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: cs.onSurface),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (isActive) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: cs.primary.withOpacity(0.12),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Text(s.activeFrameLabel, style: TextStyle(color: cs.primary, fontSize: 11, fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      ],
                                    ),
                                    if (noCustomName) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        BleDisplayName.fallbackTitle(f.bleRemoteId ?? f.deviceId),
                                        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, fontFamily: 'monospace'),
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
                                    const SizedBox(height: 8),
                                    _FrameMetricsRow(status: _frameStatuses[f.deviceId]),
                                  ],
                                ),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: s.shareToFamily,
                                    onPressed: () => unawaited(_shareInvite(s)),
                                    icon: Icon(Icons.ios_share, color: cs.primary, size: 20),
                                  ),
                                  PopupMenuButton<String>(
                                    tooltip: s.remove,
                                    onSelected: (value) {
                                      if (value == 'remove') unawaited(_confirmRemoveFrame(s, f));
                                    },
                                    icon: Icon(Icons.more_horiz, color: cs.onSurfaceVariant, size: 20),
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

class _FrameMetricsRow extends StatelessWidget {
  const _FrameMetricsRow({this.status});

  final FrameStatus? status;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final st = status;
    if (st == null) return const SizedBox.shrink();

    return Column(
      children: [
        Row(
          children: [
            Icon(Icons.battery_std_outlined, size: 16, color: const Color(0xFF4CAF50)),
            const SizedBox(width: 8),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: st.batteryFraction,
                  minHeight: 6,
                  backgroundColor: cs.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    st.battery > 20 ? const Color(0xFF4CAF50) : Colors.redAccent,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text('${st.battery}%', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.sd_storage, size: 16, color: cs.primary),
            const SizedBox(width: 8),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: st.storageFraction,
                  minHeight: 6,
                  backgroundColor: cs.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text('${st.storageUsedFormatted} / ${st.storageTotalFormatted}',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          ],
        ),
      ],
    );
  }
}
