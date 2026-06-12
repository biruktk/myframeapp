import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:app_settings/app_settings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../l10n/app_strings.dart';
import '../models/pairing_nav_result.dart';
import '../services/ble_display_name.dart';
import '../services/ble_frame_scan_filter.dart';
import '../services/ble_permissions_util.dart';
import '../config/vps_defaults.dart';
import '../services/device_store.dart';
import '../services/pairing_mqtt_presetup.dart';
import 'wifi_provision_screen.dart';
import '../navigation/pairing_flow_nav.dart';
import '../services/app_diag_log.dart';
import '../services/app_release_guard.dart';
import '../widgets/debug_slog_overlay.dart';

class DeviceDiscoveryScreen extends StatefulWidget {
  const DeviceDiscoveryScreen({
    super.key,
    this.openSendAfterSetup = true,
  });

  /// When false (e.g. editor mid-upload), stay on current screen after pairing.
  final bool openSendAfterSetup;

  @override
  State<DeviceDiscoveryScreen> createState() => _DeviceDiscoveryScreenState();
}

class _BleTileRow {
  _BleTileRow({
    required this.id,
    required this.rssi,
    required this.effectiveName,
    required this.scan,
    required this.nativeServiceUuids,
  });

  final String id;
  int rssi;
  String effectiveName;
  final ScanResult? scan;
  final List<String> nativeServiceUuids;

  BluetoothDevice get device => scan?.device ?? BluetoothDevice.fromId(id);

  String get displayTitle {
    final n = effectiveName.trim();
    if (n.isEmpty) return ''; // caller uses Unknown label
    return n;
  }
}

class _DeviceDiscoveryScreenState extends State<DeviceDiscoveryScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  static const MethodChannel _nativeBleMethod =
      MethodChannel('myframe/native_ble/methods');
  static const EventChannel _nativeBleEvents =
      EventChannel('myframe/native_ble/events');
  static const Duration _scanSessionDuration = Duration(seconds: 30);
  static final bool _useNativeBle = Platform.isAndroid;

  final Map<String, ScanResult> _found = {};
  final Map<String, ({String name, int rssi, List<String> serviceUuids})>
      _nativeFound = {};
  StreamSubscription<List<ScanResult>>? _sub;
  StreamSubscription<dynamic>? _nativeSub;
  StreamSubscription<BluetoothAdapterState>? _adapterSub;
  StreamSubscription<bool>? _isScanningSub;
  StreamSubscription<BluetoothConnectionState>? _connSub;
  StreamSubscription<List<int>>? _notifySub;
  Timer? _scanRetryTimer;
  DateTime? _lastRxAt;
  late final AnimationController _sweepCtrl;
  late final AnimationController _pulseCtrl;
  String? _lastDetectedId;
  BluetoothDevice? _connectedDevice;
  String? _connectedDeviceId;
  String? _connectingDeviceId;
  int _receivedBytes = 0;
  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;
  bool _scanning = false;
  bool _startingScan = false;
  bool _scanSuspended = false;
  String? _error;
  BleScanPermissionOutcome? _permOutcome;
  _BleTileRow? _connectFailedRow;
  String? _connectFailureMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sweepCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _isScanningSub = FlutterBluePlus.isScanning.listen((v) {
      if (!mounted) return;
      setState(() => _scanning = v);
    });
    if (_useNativeBle) {
      _nativeSub = _nativeBleEvents.receiveBroadcastStream().listen((event) {
        if (event is! Map) return;
        final type = event['type']?.toString();
        if (type == 'error') {
          final msg = event['message']?.toString() ?? 'native_scan_error';
          if (!mounted) return;
          setState(() => _error = msg);
          return;
        }
        if (type != 'result') return;
        final id = event['id']?.toString() ?? '';
        if (id.isEmpty) return;
        final name = event['name']?.toString() ?? '';
        final rssi = (event['rssi'] as num?)?.toInt() ?? -127;
        final rawSvcs = event['serviceUuids'];
        final svcs = <String>[];
        if (rawSvcs is List) {
          for (final e in rawSvcs) {
            if (e != null) svcs.add(e.toString());
          }
        }
        if (!mounted) return;
        setState(() {
          _nativeFound[id] = (name: name, rssi: rssi, serviceUuids: svcs);
        });
      });
    }
    _adapterSub = FlutterBluePlus.adapterState.listen((state) {
      if (!mounted) return;
      setState(() {
        _adapterState = state;
      });
      if (state == BluetoothAdapterState.on && !_scanSuspended) {
        AppDiagLog.verbose('[BLE] adapter on, starting scan');
        unawaited(_startUserBleScan());
      } else {
        unawaited(_stopUserScan());
        if (mounted) {
          setState(() {
            _scanning = false;
            _error = 'Bluetooth is off. Turn it on to scan.';
          });
        }
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _scanSuspended) return;
      if (Platform.isAndroid) {
        final pre = await requestBleScanPermissions();
        if (mounted) setState(() => _permOutcome = pre);
      }
      if (!mounted || _scanSuspended) return;
      unawaited(_startUserBleScan());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sweepCtrl.dispose();
    _pulseCtrl.dispose();
    _adapterSub?.cancel();
    _isScanningSub?.cancel();
    _nativeSub?.cancel();
    _connSub?.cancel();
    _notifySub?.cancel();
    _scanRetryTimer?.cancel();
    _sub?.cancel();
    unawaited(_disconnectTelemetry());
    unawaited(_stopUserScan());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_scanSuspended) return;
    if (state == AppLifecycleState.resumed) {
      if (_adapterState == BluetoothAdapterState.on) {
        unawaited(_startUserBleScan());
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      unawaited(_stopUserScan());
    }
  }

  String _effectiveName(ScanResult r) {
    final adv = r.advertisementData.advName.trim();
    if (adv.isNotEmpty) return adv;
    final pn = r.device.platformName.trim();
    if (pn.isNotEmpty) return pn;
    return r.device.advName.trim();
  }

  List<_BleTileRow> _buildRows() {
    final byId = <String, _BleTileRow>{};
    for (final r in _found.values) {
      final id = r.device.remoteId.str;
      final native = _nativeFound[id];
      byId[id] = _BleTileRow(
        id: id,
        rssi: r.rssi,
        effectiveName: _effectiveName(r),
        scan: r,
        nativeServiceUuids: native?.serviceUuids ?? const [],
      );
    }
    for (final e in _nativeFound.entries) {
      if (byId.containsKey(e.key)) {
        final existing = byId[e.key]!;
        if (existing.effectiveName.trim().isEmpty &&
            e.value.name.trim().isNotEmpty) {
          byId[e.key] = _BleTileRow(
            id: e.key,
            rssi: existing.rssi,
            effectiveName: e.value.name,
            scan: existing.scan,
            nativeServiceUuids: e.value.serviceUuids,
          );
        }
        continue;
      }
      byId[e.key] = _BleTileRow(
        id: e.key,
        rssi: e.value.rssi,
        effectiveName: e.value.name,
        scan: null,
        nativeServiceUuids: e.value.serviceUuids,
      );
    }
    final rows = byId.values.where((row) {
      final uuids = row.scan?.advertisementData.serviceUuids ?? const <Guid>[];
      return BleFrameScanFilter.isDiscoverableEntry(
        effectiveName: row.effectiveName,
        serviceUuids: uuids,
        nativeServiceUuidStrings: row.nativeServiceUuids,
      );
    }).toList()
      ..sort((a, b) => b.rssi.compareTo(a.rssi));
    return rows;
  }

  Future<void> _stopUserScan() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
    try {
      if (_useNativeBle) {
        await _nativeBleMethod.invokeMethod<bool>('stopNativeBleScan');
      }
    } catch (_) {}
  }

  Future<void> _startUserBleScan({bool clearList = false}) async {
    if (_scanSuspended) return;
    if (_startingScan) return;
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      if (mounted) {
        setState(() => _error = AppStrings.of(context).bleForegroundRequired);
      }
      return;
    }
    _startingScan = true;
    final s = AppStrings.of(context);
    if (clearList) {
      setState(() {
        _found.clear();
        _nativeFound.clear();
        _error = null;
        _connectFailedRow = null;
        _connectFailureMessage = null;
      });
    } else {
      setState(() => _error = null);
    }
    try {
      if (!await FlutterBluePlus.isSupported) {
        setState(() {
          _scanning = false;
          _error = s.bluetoothNotSupported;
        });
        return;
      }
      final perm = await requestBleScanPermissions();
      _permOutcome = perm;
      if (!perm.allGranted) {
        setState(() {
          _scanning = false;
          _error = s.blePermissionNearbyBody;
        });
        return;
      }
      if (!await FlutterBluePlus.isOn) {
        setState(() {
          _scanning = false;
          _error = s.bluetoothTurnOnHint;
        });
        return;
      }

      if (_useNativeBle) {
        await _nativeBleMethod.invokeMethod<bool>('startNativeBleScan');
      }

      _sub ??= FlutterBluePlus.scanResults.listen((results) {
        var changed = false;
        for (final r in results) {
          final key = r.device.remoteId.str;
          final firstSeen = !_found.containsKey(key);
          _found[key] = r;
          changed = true;
          if (firstSeen) {
            _lastDetectedId = key;
            _pulseCtrl
              ..stop()
              ..forward(from: 0);
          }
        }
        if (changed && mounted) setState(() {});
      });

      await FlutterBluePlus.stopScan();
      await Future<void>.delayed(const Duration(milliseconds: 280));

      await FlutterBluePlus.startScan(
        timeout: _scanSessionDuration,
        continuousUpdates: false,
        androidUsesFineLocation: true,
        androidScanMode: AndroidScanMode.lowLatency,
        androidCheckLocationServices: true,
      );
      AppDiagLog.verbose(
            '[BLE] scan active (${_scanSessionDuration.inSeconds}s low-latency)');
    } catch (e) {
      final raw = e.toString();
      AppDiagLog.verbose('[BLE] scan error $raw');
      final tooFrequent =
          raw.toLowerCase().contains('scanning too frequently') ||
              raw.contains('status=6');
      final iosPermissionish = Platform.isIOS &&
          (raw.toLowerCase().contains('unauthorized') ||
              raw.toLowerCase().contains('permission') ||
              raw.toLowerCase().contains('not permitted'));
      if (mounted) {
        setState(() {
          _error = tooFrequent
              ? 'Scanner busy. Retrying automatically…'
              : (iosPermissionish
                  ? 'Bluetooth access is blocked for MyFrame on this iPhone. Open iPhone Settings, allow Bluetooth, then restart the scan.'
                  : AppDiagLog.userFacingStatus(
                      raw,
                      fallback: 'Bluetooth scan failed. Try again.',
                    ));
          _scanning = false;
        });
      }
      if (tooFrequent) {
        _scheduleScanRetry(const Duration(seconds: 4));
      }
    } finally {
      _startingScan = false;
    }
  }

  void _scheduleScanRetry(Duration wait) {
    _scanRetryTimer?.cancel();
    _scanRetryTimer = Timer(wait, () {
      if (!mounted || _scanSuspended) return;
      unawaited(_startUserBleScan());
    });
  }

  Future<void> _manualRestartScan() async {
    await _stopUserScan();
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted || _scanSuspended) return;
    await _startUserBleScan(clearList: true);
  }

  Future<void> _manualStopScan() async {
    await _stopUserScan();
    if (mounted) setState(() => _scanning = false);
  }

  Future<void> _selectRow(_BleTileRow row) async {
    if (_connectingDeviceId != null) return;
    final s = AppStrings.of(context);
    try {
      final adv = row.effectiveName.trim();
      final dn = row.device.advName.trim();
      final pn = row.device.platformName.trim();
      AppDiagLog.verbose(
        '[BLE] connect tap remoteId=${row.id} rssi=${row.rssi} '
        'effectiveName="$adv" deviceAdvName="$dn" platformName="$pn"',
      );
      setState(() {
        _connectingDeviceId = row.id;
        _connectFailedRow = null;
        _connectFailureMessage = null;
      });
      final ok = await _connectForRealtimeData(row.device);
      if (!ok) {
        if (!mounted) return;
        setState(() {
          _connectingDeviceId = null;
          _connectFailedRow = row;
          _connectFailureMessage = s.bleConnectTimeoutMessage;
        });
        return;
      }
      if (_connectedDevice?.remoteId.str != row.id) {
        if (!mounted) return;
        setState(() => _connectingDeviceId = null);
        return;
      }
      if (!mounted) return;
      final remoteMac = row.id;
      final advPrefer = adv.isNotEmpty ? adv : (pn.isNotEmpty ? pn : dn);
      final displayPrefix = advPrefer.isNotEmpty
          ? advPrefer
          : BleDisplayName.fallbackTitle(remoteMac);
      AppDiagLog.verbose(
        '[BLE] saveManualPairing deviceId=$remoteMac bleRemoteId=$remoteMac bleNamePrefix=$displayPrefix',
      );
      await DeviceStore.instance.saveManualPairing(
        deviceId: remoteMac,
        bleNamePrefix: displayPrefix,
        bleRemoteId: remoteMac,
      );
      if (!mounted) return;
      _scanSuspended = true;
      try {
        await _stopUserScan();
      } catch (_) {}
      await _disconnectTelemetry();
      AppDiagLog.verbose('[BLE] sending mqtt_config before Wi‑Fi (EspBlufi order)…');
      final serverConfigSent = await PairingMqttPresetup.sendDefaultBrokerBeforeWifi();
      AppDiagLog.verbose(
        '[BLE] mqtt_config pre-Wi‑Fi ok=$serverConfigSent broker=${VpsDefaults.host}:${VpsDefaults.mqttPort}',
      );
      if (!mounted) return;
      AppDiagLog.verbose('[BLE] opening WifiProvisionScreen…');
      final wifiResult = await SafeNav.push<PairingNavResult>(
        context,
        MaterialPageRoute<PairingNavResult>(
          builder: (_) => WifiProvisionScreen(
            firstTimeSetup: true,
            serverConfigAlreadySent: serverConfigSent,
            openSendAfterSetup: widget.openSendAfterSetup,
          ),
        ),
      );
      AppDiagLog.verbose(
        '[BLE] WifiProvisionScreen closed success=${wifiResult?.success}',
      );
      _scanSuspended = false;
      unawaited(_startUserBleScan());
      if (!mounted) return;
      if (wifiResult?.success == true) {
        await _disconnectTelemetry();
      }
      if (mounted) setState(() => _connectingDeviceId = null);
      if (widget.openSendAfterSetup) {
        PairingFlowNav.onComplete(wifiResult);
      }
      await SafeNav.popPairingResult(
        context,
        result: wifiResult ?? const PairingNavResult(success: false),
      );
    } catch (e, st) {
      AppDiagLog.verbose('[BLE] _selectRow failed: $e\n$st');
      _scanSuspended = false;
      if (!mounted) return;
      setState(() {
        _connectingDeviceId = null;
        _connectFailedRow = row;
        _connectFailureMessage = s.bleConnectTimeoutMessage;
      });
    }
  }

  Future<bool> _connectForRealtimeData(BluetoothDevice device) async {
          AppDiagLog.verbose(
        '[BLE] _connectForRealtimeData start remoteId=${device.remoteId.str} '
        'advName="${device.advName}" platformName="${device.platformName}"',
      );
    await _disconnectTelemetry();
    try {
      setState(() {
        _connectedDevice = device;
        _connectedDeviceId = device.remoteId.str;
      });
      AppDiagLog.verbose('[BLE] GATT connect (15s timeout)…');
      await device.connect(timeout: const Duration(seconds: 15));
              AppDiagLog.verbose(
            '[BLE] connected remoteId=${device.remoteId.str} isConnected=${device.isConnected} mtu=${device.mtuNow}');
      _connSub = device.connectionState.listen((state) {
        if (!mounted) return;
        AppDiagLog.verbose(
              '[BLE] connectionState → ${state.name} (${device.remoteId.str})');
        if (state == BluetoothConnectionState.disconnected) {
          setState(() {
            _connectedDevice = null;
            _connectedDeviceId = null;
          });
        } else {
          setState(() {
            _connectedDevice = device;
            _connectedDeviceId = device.remoteId.str;
          });
        }
      });

      AppDiagLog.verbose('[BLE] discoverServices (15s)…');
      final services = await device.discoverServices(timeout: 15);
              AppDiagLog.verbose(
            '[BLE] services count=${services.length}: ${services.map((s) => s.uuid.str).join(", ")}');
      BluetoothCharacteristic? notifyChar;
      for (final s in services) {
        for (final c in s.characteristics) {
          if (c.properties.notify || c.properties.indicate) {
            notifyChar = c;
            break;
          }
        }
        if (notifyChar != null) break;
      }
      if (notifyChar != null) {
        AppDiagLog.verbose('[BLE] setNotifyValue on ${notifyChar.uuid.str}');
        try {
          await notifyChar.setNotifyValue(true);
          _notifySub = notifyChar.lastValueStream.listen((data) {
            if (!mounted) return;
            if (data.isEmpty) return;
            AppDiagLog.verbose('[BLE] notify rx ${data.length} bytes');
            setState(() {
              _lastRxAt = DateTime.now();
              _receivedBytes += data.length;
            });
          });
        } catch (e) {
          AppDiagLog.verbose(
                '[BLE] setNotifyValue failed (continuing as connected): $e');
        }
      }
      AppDiagLog.verbose(
            '[BLE] _connectForRealtimeData success for ${device.remoteId.str}');
      return true;
    } catch (e, st) {
              AppDiagLog.verbose(
            '[BLE] _connectForRealtimeData FAILED remoteId=${device.remoteId.str}: $e');
        AppDiagLog.verbose('[BLE] stack: $st');
      if (!mounted) return false;
      setState(() {
        _connectedDevice = null;
        _connectedDeviceId = null;
      });
      try {
        if (device.isConnected) await device.disconnect();
      } catch (_) {}
      return false;
    }
  }

  Future<void> _disconnectTelemetry() async {
    await _notifySub?.cancel();
    _notifySub = null;
    await _connSub?.cancel();
    _connSub = null;
    final d = _connectedDevice;
    _connectedDevice = null;
    _connectedDeviceId = null;
    if (d != null) {
      try {
        if (d.isConnected) {
          await d.disconnect();
        }
      } catch (_) {}
    }
  }

  Future<void> _retryFailedConnect() async {
    final row = _connectFailedRow;
    if (row == null) return;
    setState(() {
      _connectFailedRow = null;
      _connectFailureMessage = null;
    });
    await _selectRow(row);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final cs = Theme.of(context).colorScheme;
    final items = _buildRows();
    final perm = _permOutcome;
    final isBtOn = _adapterState == BluetoothAdapterState.on;
    final receiving = _lastRxAt != null &&
        DateTime.now().difference(_lastRxAt!) < const Duration(seconds: 3);
    final connected = _connectedDevice?.isConnected == true;
    final liveStatus = !isBtOn
        ? 'Bluetooth Off'
        : receiving
            ? 'Receiving Data'
            : connected
                ? 'Connected'
                : _scanning
                    ? s.bleScanningEllipsis
                    : 'Idle';
    final permissionTitle = Platform.isIOS
        ? 'Bluetooth access required on iPhone'
        : s.blePermissionNearbyTitle;
    final permissionBody = Platform.isIOS
        ? 'iPhone needs Bluetooth permission so MyFrame can discover nearby frames. Open iPhone Settings, allow Bluetooth for MyFrame, then restart the scan.'
        : s.blePermissionNearbyBody;
    final bluetoothSettingsLabel =
        Platform.isIOS ? 'Open iPhone Settings' : s.openBluetoothSystemSettings;

    return DebugSlogOverlay(
      child: Scaffold(
      appBar: AppBar(
        title: Text(s.scanDeviceTitle),
        actions: [
          IconButton(
            onPressed: () => unawaited(_manualRestartScan()),
            icon: const Icon(Icons.restart_alt),
            tooltip: s.bleRestartScan,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (perm != null && !perm.allGranted) ...[
            Card(
              color: cs.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(permissionTitle,
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: cs.onErrorContainer)),
                    const SizedBox(height: 8),
                    Text(permissionBody,
                        style: TextStyle(
                            color: cs.onErrorContainer, height: 1.35)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (perm.needsBluetoothSettings)
                          FilledButton.tonalIcon(
                            onPressed: () {
                              if (Platform.isIOS) {
                                AppSettings.openAppSettings(
                                    type: AppSettingsType.settings);
                              } else {
                                AppSettings.openAppSettings(
                                    type: AppSettingsType.bluetooth);
                              }
                            },
                            icon: const Icon(Icons.bluetooth),
                            label: Text(bluetoothSettingsLabel),
                          ),
                        if (perm.needsLocationSettings)
                          FilledButton.tonalIcon(
                            onPressed: () => AppSettings.openAppSettings(
                                type: AppSettingsType.location),
                            icon: const Icon(Icons.location_on_outlined),
                            label: Text(s.openLocationSystemSettings),
                          ),
                        OutlinedButton.icon(
                          onPressed: () => AppSettings.openAppSettings(
                              type: AppSettingsType.settings),
                          icon: const Icon(Icons.app_settings_alt_outlined),
                          label: Text(s.openAppPermissionSettings),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Container(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  cs.primary.withValues(alpha: 0.12),
                  cs.surfaceContainerHighest,
                ],
              ),
              border: Border.all(color: cs.primary.withValues(alpha: 0.28)),
            ),
            child: Column(
              children: [
                SizedBox(
                  height: 190,
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_sweepCtrl, _pulseCtrl]),
                    builder: (context, _) {
                      return _RadarScanner(
                        sweepT: _sweepCtrl.value,
                        pulseT: _pulseCtrl.value,
                        active: _scanning,
                        color: cs.primary,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_scanning) ...[
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Text(
                      liveStatus,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  s.scanDeviceBody,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: cs.onSurfaceVariant, fontSize: 12, height: 1.35),
                ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: (_startingScan || _scanSuspended)
                          ? null
                          : () => unawaited(_manualStopScan()),
                      icon: const Icon(Icons.stop_circle_outlined),
                      label: Text(s.bleStopScan),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: (_startingScan || _scanSuspended)
                          ? null
                          : () => unawaited(_manualRestartScan()),
                      icon: const Icon(Icons.restart_alt),
                      label: Text(s.bleRestartScan),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _chip(context,
                        icon: Icons.bluetooth_searching,
                        text: _scanning ? s.bleScanningEllipsis : 'Scan idle'),
                    _chip(context,
                        icon: Icons.devices, text: '${items.length} nearby'),
                    if (_lastDetectedId != null)
                      _chip(context,
                          icon: Icons.check_circle, text: 'Detected'),
                    if (connected)
                      _chip(context, icon: Icons.link, text: 'Connected'),
                    if (receiving)
                      _chip(context, icon: Icons.sync, text: 'Receiving'),
                  ],
                ),
                if (AppDiagLog.isDebugEnabled && perm != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Adapter: ${_adapterState.name} · Perms granted: ${perm.allGranted}',
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11),
                  ),
                ],
                if (AppDiagLog.isDebugEnabled && _connectedDeviceId != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Device: $_connectedDeviceId · Rx $_receivedBytes B',
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_scanning) const LinearProgressIndicator(minHeight: 3),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: TextStyle(color: cs.error)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => unawaited(_manualRestartScan()),
                  icon: const Icon(Icons.restart_alt),
                  label: Text(s.bleRestartScan),
                ),
              ],
            ),
          ],
          if (_connectingDeviceId != null) ...[
            const SizedBox(height: 12),
            ListTile(
              leading: const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              title: Text(s.bleConnectingSpinnerLabel),
              subtitle: Text(
                s.bleConnectingStayNear,
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
            ),
          ],
          if (_connectFailedRow != null && _connectFailureMessage != null) ...[
            const SizedBox(height: 8),
            Card(
              color: cs.errorContainer,
              child: ListTile(
                title: Text(_connectFailureMessage!,
                    style: TextStyle(color: cs.onErrorContainer)),
                trailing: FilledButton(
                  onPressed: _connectingDeviceId != null
                      ? null
                      : () => unawaited(_retryFailedConnect()),
                  child: Text(s.bleTryAgain),
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          if (!_scanning &&
              items.isEmpty &&
              (_permOutcome?.allGranted ?? false) &&
              _error == null)
            ListTile(
              leading: const Icon(Icons.bluetooth_searching),
              title: Text(s.noDeviceFoundTitle),
              subtitle: Text(s.noDeviceFoundBody),
            ),
          for (final row in items)
            Card(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          backgroundColor: cs.primary.withValues(alpha: 0.12),
                          child: Icon(Icons.bluetooth, color: cs.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                row.displayTitle.isEmpty
                                    ? s.bleUnknownDeviceLabel
                                    : row.displayTitle,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 16),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '[${BleDisplayName.macSuffixHex4(row.id)}]',
                                style: TextStyle(
                                    color: cs.onSurfaceVariant,
                                    fontWeight: FontWeight.w600),
                              ),
                              if (AppDiagLog.isDebugEnabled) ...[
                                const SizedBox(height: 4),
                                Text(
                                  s.bleDebugAdvertLine(
                                      row.effectiveName.isEmpty
                                          ? '(empty)'
                                          : row.effectiveName,
                                      row.id),
                                  style: TextStyle(
                                      fontSize: 11, color: cs.tertiary),
                                ),
                              ],
                            ],
                          ),
                        ),
                        FilledButton(
                          onPressed:
                              (_connectingDeviceId != null || _scanSuspended)
                                  ? null
                                  : () => unawaited(_selectRow(row)),
                          child: Text(s.bleConnect),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                            child: _RssiStrengthBar(
                                rssi: row.scan?.rssi ?? row.rssi)),
                        const SizedBox(width: 10),
                        Text('${row.scan?.rssi ?? row.rssi} dBm',
                            style: TextStyle(
                                fontSize: 12, color: cs.onSurfaceVariant)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
    );
  }

  Widget _chip(BuildContext context,
      {required IconData icon, required String text}) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: cs.primary),
          const SizedBox(width: 6),
          Text(text,
              style: TextStyle(
                  color: cs.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12)),
        ],
      ),
    );
  }
}

class _RssiStrengthBar extends StatelessWidget {
  const _RssiStrengthBar({required this.rssi});

  final int rssi;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = ((rssi + 100) / 60).clamp(0.0, 1.0);
    final filled = (t * 4).round().clamp(0, 4);
    return Row(
      children: List.generate(4, (i) {
        final on = i < filled;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < 3 ? 4 : 0),
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                color: on ? cs.primary : cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: cs.outlineVariant),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _RadarScanner extends StatelessWidget {
  const _RadarScanner({
    required this.sweepT,
    required this.pulseT,
    required this.active,
    required this.color,
  });

  final double sweepT;
  final double pulseT;
  final bool active;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final sweepAngle = sweepT * 2 * math.pi;
    final pulseScale = 1 + (0.06 * Curves.easeOut.transform(pulseT));
    return Center(
      child: Transform.scale(
        scale: pulseScale,
        child: SizedBox(
          width: 188,
          height: 188,
          child: CustomPaint(
            painter: _RadarPainter(
              color: color,
              sweepAngle: sweepAngle,
              pulse: pulseT,
              active: active,
            ),
          ),
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({
    required this.color,
    required this.sweepAngle,
    required this.pulse,
    required this.active,
  });

  final Color color;
  final double sweepAngle;
  final double pulse;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..color = color.withValues(alpha: 0.22)
      ..strokeWidth = 1.2;
    canvas.drawCircle(c, r, base);
    canvas.drawCircle(c, r * 0.74, base);
    canvas.drawCircle(c, r * 0.48, base);
    canvas.drawCircle(c, r * 0.22, base);

    final axis = Paint()
      ..color = color.withValues(alpha: 0.16)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(c.dx - r, c.dy), Offset(c.dx + r, c.dy), axis);
    canvas.drawLine(Offset(c.dx, c.dy - r), Offset(c.dx, c.dy + r), axis);

    final sweepRect = Rect.fromCircle(center: c, radius: r);
    final sweep = Paint()
      ..style = PaintingStyle.fill
      ..shader = SweepGradient(
        startAngle: sweepAngle - 0.9,
        endAngle: sweepAngle + 0.28,
        colors: [
          color.withValues(alpha: 0.00),
          color.withValues(alpha: active ? 0.12 : 0.04),
          color.withValues(alpha: active ? 0.48 : 0.12),
        ],
      ).createShader(sweepRect);
    canvas.drawCircle(c, r, sweep);

    final pingPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = color.withValues(alpha: (1 - pulse) * 0.45);
    canvas.drawCircle(c, r * (0.18 + pulse * 0.72), pingPaint);

    final dot = Paint()..color = color.withValues(alpha: active ? 1 : 0.5);
    canvas.drawCircle(c, 4, dot);
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) {
    return oldDelegate.sweepAngle != sweepAngle ||
        oldDelegate.pulse != pulse ||
        oldDelegate.active != active ||
        oldDelegate.color != color;
  }
}
