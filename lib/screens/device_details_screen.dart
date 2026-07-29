import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../services/account_sync_service.dart';
import '../services/device_store.dart';
import '../services/frame_api_client.dart';
import '../services/frame_mac_util.dart';

class DeviceDetailsScreen extends StatefulWidget {
  const DeviceDetailsScreen({super.key});

  @override
  State<DeviceDetailsScreen> createState() => _DeviceDetailsScreenState();
}

class _DeviceDetailsScreenState extends State<DeviceDetailsScreen> {
  PairedFrame? _paired;
  FrameStatus? _status;
  Timer? _pollTimer;
  final FrameApiClient _api = FrameApiClient();

  @override
  void initState() {
    super.initState();
    _load();
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _api.close();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) => _fetch());
  }

  Future<void> _load() async {
    await DeviceStore.instance.load();
    if (mounted) {
      setState(() => _paired = DeviceStore.instance.cached);
      await _fetch();
    }
  }

  Future<void> _fetch() async {
    final p = _paired;
    if (p == null) return;
    final mac = _resolveMac;
    if (mac == null || mac.length != 12) return;
    try {
      final st = await _api.fetchFrameStatus(mac: mac);
      if (mounted) setState(() => _status = st);
    } catch (_) {}
  }

  String? get _resolveMac {
    final p = _paired;
    if (p == null) return null;
    return DeviceStore.instance.pairedFrameMac ??
        FrameMacUtil.macFromBleName(p.bleNamePrefix ?? '') ??
        FrameMacUtil.normalizeSlug(p.deviceId);
  }

  String get _deviceName => _paired?.frameName?.trim().isNotEmpty == true
      ? _paired!.frameName!
      : (_paired?.listDisplayTitle(AppStrings(AppLocale.en)) ?? 'MyFrame');

  String get _macAddress {
    // Use the hardware MAC (from BLE name or pairedFrameMac store), NOT the iOS
    // CoreBluetooth peripheral UUID stored in deviceId — iOS never exposes the
    // real BLE MAC to apps, so deviceId is a random UUID on iOS.
    final hex = (_resolveMac ?? '').toUpperCase();
    if (hex.length == 12) {
      return '${hex.substring(0, 2)}:${hex.substring(2, 4)}:${hex.substring(4, 6)}:${hex.substring(6, 8)}:${hex.substring(8, 10)}:${hex.substring(10, 12)}';
    }
    // Fallback: try to extract 12 hex digits from deviceId (covers colon-separated or raw)
    final p = _paired;
    if (p == null) return '--';
    final rawHex = p.deviceId.replaceAll(RegExp(r'[^0-9a-fA-F]'), '').toUpperCase();
    if (rawHex.length >= 12) {
      final s = rawHex.substring(rawHex.length - 12);
      return '${s.substring(0, 2)}:${s.substring(2, 4)}:${s.substring(4, 6)}:${s.substring(6, 8)}:${s.substring(8, 10)}:${s.substring(10, 12)}';
    }
    return '--';
  }

  String get _wifiSsid {
    final p = _paired;
    final st = _status;
    if (p?.wifiSsid?.trim().isNotEmpty == true) return p!.wifiSsid!;
    if (st != null && st.wifiSsid.isNotEmpty) return st.wifiSsid;
    return '--';
  }

  String _lastSeen(AppStrings s) {
    final st = _status;
    if (st == null) return '--';
    final ms = st.lastSeenMs;
    if (ms == null || ms <= 0) return '--';
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return s.justNow;
    if (diff.inMinutes < 60) return s.minutesAgo(diff.inMinutes);
    if (diff.inHours < 24) return s.hoursAgo(diff.inHours);
    if (diff.inDays < 7) return s.daysAgo(diff.inDays);
    return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _confirmDelete() async {
    final p = _paired;
    if (p == null) return;
    final s = AppStrings.of(context);
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.deleteDevice),
        content: Text(s.deleteDeviceConfirm(_deviceName)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.deleteButton, style: const TextStyle(color: Color(0xFFE53935))),
          ),
        ],
      ),
    );
    if (go != true || !mounted) return;

    final mac = _resolveMac;
    if (mac != null) {
      await _api.deleteFrame(mac: mac, pairingToken: p.pairingToken);
    }
    await AccountSyncService.instance.deleteFrame(p.deviceId);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  static const _red = Color(0xFFE53935);
  static const _bg = Color(0xFFF6F7F9);
  static const _cardBorder = Color(0xFFEFEFEF);

  String _storageText() {
    final st = _status;
    return '${st?.storageUsedFormatted ?? '0.0 GB'} / ${st?.storageTotalFormatted ?? '32.0 GB'}';
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final p = _paired;
    final st = _status;
    final isOnline = st?.isEffectivelyOnline ?? false;
    final battery = st?.battery ?? 100;
    final storageRatio = st?.storageFraction ?? 0;
    final firmware = 'v0.5.0';

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: Text(
          s.deviceDetails,
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: Colors.black, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _heroCard(_deviceName, _macAddress, isOnline, s),
              const SizedBox(height: 16),
              _sectionHeader(s.statusSection),
              _card(
                child: Column(
                  children: [
                    _statusRow(
                      icon: Icons.battery_std_outlined,
                      label: s.batteryLabel,
                      child: Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: battery / 100.0,
                                minHeight: 6,
                                backgroundColor: const Color(0xFFEEEEEE),
                                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '$battery%',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _statusRow(
                      icon: Icons.sd_storage_outlined,
                      label: s.storageLabel,
                      child: Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: storageRatio,
                                minHeight: 6,
                                backgroundColor: const Color(0xFFEEEEEE),
                                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _storageText(),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.black87),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _sectionHeader(s.deviceInfoSection),
              _card(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _infoTile(s.macLabel, _macAddress),
                    _divider,
                    _infoTile(s.firmwareVersionLabel, firmware),
                    _divider,
                    _infoTile(s.networkNameLabel, _wifiSsid),
                    _divider,
                    _infoTile(s.lastSeenLabel, _lastSeen(s)),
                    _divider,
                    _infoTile(s.wifiSignalLabel, isOnline ? s.connected : s.disconnected),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Center(
                child: SizedBox(
                  width: 220,
                  height: 44,
                  child: OutlinedButton(
                    onPressed: p == null ? null : _confirmDelete,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: _red, width: 1.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      s.deleteDevice,
                      style: const TextStyle(color: _red, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heroCard(String name, String mac, bool online, AppStrings s) {
    return _card(
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: _red,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.cast, color: Colors.white, size: 32),
          ),
          const SizedBox(height: 12),
          Text(
            name,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 4),
          Text(
            mac,
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.circle,
                size: 8,
                color: online ? const Color(0xFF4CAF50) : Colors.grey,
              ),
              const SizedBox(width: 6),
              Text(
                online ? s.onlineStatus : s.offlineStatus,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: online ? const Color(0xFF4CAF50) : Colors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
      ),
      child: child,
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _statusRow({
    required IconData icon,
    required String label,
    required Widget child,
  }) {
    return Row(
      children: [
        Icon(icon, color: _red, size: 20),
        const SizedBox(width: 8),
        SizedBox(
          width: 56,
          child: Text(label, style: const TextStyle(fontSize: 14, color: Colors.black87)),
        ),
        const SizedBox(width: 16),
        Expanded(child: child),
      ],
    );
  }

  Widget _infoTile(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 14, color: Colors.black87)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

const _divider = Divider(height: 1, indent: 16, endIndent: 16, color: Color(0xFFF0F0F0));
