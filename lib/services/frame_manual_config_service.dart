import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:http/http.dart' as http;

import '../config/vps_defaults.dart';
import 'ble_frame_scan_filter.dart';
import 'ble_permissions_util.dart';
import 'blufi_provisioning_service.dart';
import 'device_store.dart';
import 'frame_mac_util.dart';
import 'app_diag_log.dart';

class FrameBleDevice {
  FrameBleDevice({
    required this.device,
    required this.name,
    required this.rssi,
    required this.mac,
  });

  final BluetoothDevice device;
  final String name;
  final int rssi;
  final String mac;
}

/// EspBluFi-style manual JSON config over BLE (iOS + Android).
class FrameManualConfigService {
  FrameManualConfigService._();

  static final FrameManualConfigService instance = FrameManualConfigService._();

  static const _defaultFrameServiceUuid =
      '0000ffff-0000-1000-8000-00805f9b34fb';
  static const _defaultFrameDataUuid = '0000ff01-0000-1000-8000-00805f9b34fb';
  static const _defaultFrameNotifyUuid = '0000ff02-0000-1000-8000-00805f9b34fb';
  static const _vendorServiceUuid = '00002760-08c2-11e1-9073-0e8ac72e1001';
  static const _vendorWriteUuid = '00002760-08c2-11e1-9073-0e8ac72e0001';
  static const _vendorNotifyUuid = '00002760-08c2-11e1-9073-0e8ac72e0002';

  BluetoothDevice? _connected;
  BluetoothCharacteristic? _writeChar;
  BluetoothCharacteristic? _notifyChar;
  List<BluetoothService> _services = const [];
  StreamSubscription<List<int>>? _notifySub;

  BluetoothDevice? get connectedDevice => _connected;

  String statusUrl(String mac) {
    final slug = FrameMacUtil.normalizeSlug(mac) ?? mac;
    return '${VpsDefaults.apiBase}/api/frames/$slug/status';
  }

  Future<bool> ensurePermissions() => ensureBlePermissionsBeforeScan();

  Future<List<FrameBleDevice>> scan({
    Duration timeout = const Duration(seconds: 15),
    void Function(String line)? onLog,
  }) async {
    if (!await ensurePermissions()) {
      throw StateError('Bluetooth permission denied');
    }
    if (!await FlutterBluePlus.isSupported) {
      throw StateError('Bluetooth LE not supported');
    }
    final adapter = await FlutterBluePlus.adapterState.first;
    if (adapter != BluetoothAdapterState.on) {
      throw StateError('Bluetooth is off');
    }

    final byId = <String, FrameBleDevice>{};
    late final StreamSubscription<List<ScanResult>> sub;
    sub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        final name = _effectiveName(r);
        if (!BleFrameScanFilter.isDiscoverableEntry(
          effectiveName: name,
          serviceUuids: r.advertisementData.serviceUuids,
        )) {
          continue;
        }
        final mac = FrameMacUtil.macFromBleName(name);
        if (mac == null) continue;
        final id = r.device.remoteId.str;
        byId[id] = FrameBleDevice(
          device: r.device,
          name: name,
          rssi: r.rssi,
          mac: mac,
        );
      }
    });

    try {
      await FlutterBluePlus.stopScan();
      onLog?.call('Scanning for MyFrame devices…');
      await FlutterBluePlus.startScan(
        timeout: timeout,
        androidUsesFineLocation: true,
        androidScanMode: AndroidScanMode.lowLatency,
      );
      await Future<void>.delayed(timeout);
    } finally {
      await FlutterBluePlus.stopScan();
      await sub.cancel();
    }
    final list = byId.values.toList()
      ..sort((a, b) => b.rssi.compareTo(a.rssi));
    onLog?.call('Found ${list.length} device(s)');
    return list;
  }

  Future<void> connect(
    BluetoothDevice device, {
    void Function(String line)? onLog,
  }) async {
    await disconnect(onLog: onLog);
    final name = device.platformName.trim().isNotEmpty
        ? device.platformName.trim()
        : device.advName.trim();
    onLog?.call('Connecting to $name…');
    await device.connect(timeout: const Duration(seconds: 12));
    _connected = device;
    onLog?.call('Connected to $name');

    final services = await device.discoverServices(timeout: 12);
    _services = services;
    final picked = _pickGatt(services);
    if (picked == null) {
      throw StateError('No writable BLE characteristic found on this frame');
    }
    _writeChar = picked.write;
    _notifyChar = picked.notify;

    if (_notifyChar != null) {
      await _notifyChar!.setNotifyValue(true);
      _notifySub = _notifyChar!.lastValueStream.listen((bytes) {
        if (bytes.isEmpty) return;
        final text = utf8.decode(bytes, allowMalformed: true);
        onLog?.call('Response: $text');
      });
      onLog?.call('Notifications enabled');
    }
    onLog?.call('Ready to send config');
  }

  Future<void> connectByRemoteId(
    String remoteId, {
    void Function(String line)? onLog,
  }) async {
    await connect(BluetoothDevice.fromId(remoteId), onLog: onLog);
  }

  Future<void> disconnect({void Function(String line)? onLog}) async {
    await _notifySub?.cancel();
    _notifySub = null;
    if (_notifyChar != null) {
      try {
        await _notifyChar!.setNotifyValue(false);
      } catch (_) {}
    }
    _writeChar = null;
    _notifyChar = null;
    _services = const [];
    final d = _connected;
    _connected = null;
    if (d != null) {
      try {
        await d.disconnect();
        onLog?.call('Disconnected');
      } catch (_) {}
    }
  }

  Future<bool> checkFrameOnServer(
    String mac, {
    void Function(String line)? onLog,
  }) async {
    onLog?.call('Checking if frame already online…');
    try {
      final slug = FrameMacUtil.normalizeSlug(mac) ?? mac;
      final uri = Uri.parse(statusUrl(slug));
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) {
        onLog?.call('Status HTTP ${res.statusCode}');
        return false;
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['online'] == true) {
        onLog?.call('✅ Frame already online!');
        await DeviceStore.instance.savePairedFrameMac(slug);
        return true;
      }
      onLog?.call('Frame not online — sending config');
      return false;
    } catch (e) {
      onLog?.call('Frame not found on server — needs config ($e)');
      return false;
    }
  }

  Future<void> sendConfig(
    String jsonText, {
    void Function(String line)? onLog,
  }) async {
    final write = _writeChar;
    if (write == null) throw StateError('Not connected');

    Map<String, dynamic> parsed;
    try {
      parsed = jsonDecode(jsonText) as Map<String, dynamic>;
    } catch (e) {
      throw FormatException('Invalid JSON — $e');
    }
    parsed['msgid'] = DateTime.now().millisecondsSinceEpoch.toString();
    final payload = jsonEncode(parsed);
    final bytes = utf8.encode(payload);
    onLog?.call('Sending ${bytes.length} bytes (EspBlufi-compatible path)…');
    await BlufiProvisioningService.instance.deliverConfigJson(
      services: _services,
      fallbackWrite: write,
      jsonBytes: bytes,
    );
    onLog?.call('Config sent! Waiting for frame…');
  }

  Future<bool> pollUntilOnline(
    String mac, {
    Duration interval = const Duration(seconds: 2),
    int maxAttempts = 15,
    void Function(String line)? onLog,
  }) async {
    final slug = FrameMacUtil.normalizeSlug(mac) ?? mac;
    // Provisioning grace window: after BluFi completes, the frame needs ~10–30s
    // to associate to Wi-Fi, acquire DHCP, and send its first MQTT login/heart.
    // During this window the backend returns `online: false` but also sets
    // `provisioning: true` and `app_paired: true`. Treat those as "still booting",
    // NOT as "not paired" — keep polling until the frame actually heartbeats.
    DateTime? firstAttemptAt;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      firstAttemptAt ??= DateTime.now();
      onLog?.call('Polling server… (attempt $attempt/$maxAttempts)');
      bool provisionedSeen = false;
      try {
        final uri = Uri.parse(statusUrl(slug));
        final res = await http.get(uri).timeout(const Duration(seconds: 8));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          if (data['online'] == true) {
            onLog?.call('✅ Frame is online! Ready to use.');
            await DeviceStore.instance.savePairedFrameMac(slug);
            return true;
          }
          // Backend hint: frame is paired but hasn't heartbeated yet. Stay
          // on the friendly "connecting…" message — do NOT surface an error.
          if (data['provisioning'] == true || data['app_paired'] == true) {
            provisionedSeen = true;
            onLog?.call('Frame is paired, waiting for first MQTT heartbeat…');
          }
        }
      } catch (e) {
        AppDiagLog.verbose('[FrameConfig] poll: $e');
      }
      if (attempt < maxAttempts) {
        await Future<void>.delayed(interval);
        // Continue polling as long as the backend reports the frame is in the
        // provisioning grace window. Only fail after the full window expires.
        if (provisionedSeen) continue;
      }
    }
    return false;
  }

  String _effectiveName(ScanResult r) {
    final adv = r.advertisementData.advName.trim();
    if (adv.isNotEmpty) return adv;
    final pn = r.device.platformName.trim();
    if (pn.isNotEmpty) return pn;
    return r.device.advName.trim();
  }

  ({BluetoothCharacteristic write, BluetoothCharacteristic? notify})? _pickGatt(
    List<BluetoothService> services,
  ) {
    for (final s in services) {
      if (!_uuidEq(s.uuid.str, _vendorServiceUuid)) continue;
      BluetoothCharacteristic? w;
      BluetoothCharacteristic? n;
      for (final c in s.characteristics) {
        if (_uuidEq(c.uuid.str, _vendorWriteUuid) &&
            (c.properties.write || c.properties.writeWithoutResponse)) {
          w = c;
        }
        if (_uuidEq(c.uuid.str, _vendorNotifyUuid) &&
            (c.properties.notify || c.properties.indicate)) {
          n = c;
        }
      }
      if (w != null) return (write: w, notify: n);
    }

    for (final s in services) {
      if (!_uuidEq(s.uuid.str, _defaultFrameServiceUuid)) continue;
      for (final c in s.characteristics) {
        if (_uuidEq(c.uuid.str, _defaultFrameDataUuid) &&
            (c.properties.write || c.properties.writeWithoutResponse)) {
          BluetoothCharacteristic? n;
          for (final s2 in services) {
            for (final c2 in s2.characteristics) {
              if (_uuidEq(c2.uuid.str, _defaultFrameNotifyUuid) &&
                  (c2.properties.notify || c2.properties.indicate)) {
                n = c2;
              }
            }
          }
          return (write: c, notify: n);
        }
      }
    }

    for (final s in services) {
      for (final c in s.characteristics) {
        if (c.properties.write || c.properties.writeWithoutResponse) {
          return (write: c, notify: null);
        }
      }
    }
    return null;
  }

  static const _btBase = '00001000800000805f9b34fb';

  bool _uuidEq(String a, String b) {
    String norm(String u) {
      final x = u.toLowerCase().replaceAll('-', '');
      if (x.length == 32 && x.endsWith(_btBase)) return x.substring(4, 8);
      if (x.length == 4) return x;
      return x;
    }

    return norm(a) == norm(b);
  }
}
