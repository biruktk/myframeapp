import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'ble_permissions_util.dart';
import 'device_store.dart';
import 'device_transport.dart';
import 'slideshow_style.dart';
import 'transport_kind.dart';

/// Default GATT UUIDs for MyFrame firmware (override via pairing QR `bleService` / `bleDataChar`).
/// Wire format: **4 bytes big‑endian total length**, then **payload** split into writes of at most [maxChunkWithResponse] bytes.
class BleMyFrameDefaults {
  BleMyFrameDefaults._();

  static const serviceUuid = '5a4bcfe1-65fb-449a-bcf3-0a1d2a3b4c5d';
  static const dataCharUuid = '5a4bcfe2-65fb-449a-bcf3-0a1d2a3b4c5d';
  static const defaultNamePrefix = 'MyFrame';

  /// Safe for “write with response” on typical 23–512 MTU devices.
  static const int maxChunkWithResponse = 200;
}

/// BLE transport with a **persistent** session: after a successful send the link stays up for the next one.
class BleFrameDeviceTransport implements DeviceTransport {
  BleFrameDeviceTransport._() {
    _emitConnection(FrameConnectionState.disconnected);
  }

  static final BleFrameDeviceTransport instance = BleFrameDeviceTransport._();

  final _controller = StreamController<FrameConnectionState>.broadcast();

  /// Latest state for UI (Send tab banner); matches [connectionState] events.
  final ValueNotifier<FrameConnectionState> connectionUi = ValueNotifier(FrameConnectionState.disconnected);

  BluetoothDevice? _device;
  BluetoothCharacteristic? _dataChar;
  StreamSubscription<BluetoothConnectionState>? _linkSub;
  String? _sessionFingerprint;

  void _emitConnection(FrameConnectionState s) {
    if (connectionUi.value != s) {
      connectionUi.value = s;
    }
    _controller.add(s);
  }

  /// User chose **Disconnect**, sending over **HTTP/Wi‑Fi** (other mode), or re-pair; also clears the session fingerprint.
  Future<void> releaseSession() async {
    await _disconnectAndClear(emit: true);
    _sessionFingerprint = null;
  }

  @override
  Stream<FrameConnectionState> get connectionState => _controller.stream;

  @override
  Future<SendResult> sendImage({
    required List<int> bytes,
    required String filename,
    required TransportKind transport,
    required SlideshowStyle slideshow,
    Duration? displayDuration,
  }) async {
    if (transport != TransportKind.bluetooth) {
      return SendResult(ok: false, message: 'BLE transport used for Bluetooth only');
    }

    if (kIsWeb) {
      return SendResult(ok: false, message: 'Bluetooth is not available on web');
    }

    try {
      final okBle = await ensureBlePermissionsBeforeScan();
      if (!okBle) {
        return SendResult(
          ok: false,
          message: 'Bluetooth permission denied (allow Bluetooth, scan, and connect).',
        );
      }

      if (!await FlutterBluePlus.isSupported) {
        return SendResult(ok: false, message: 'Bluetooth LE is not supported on this device');
      }
      if (!await FlutterBluePlus.isOn) {
        return SendResult(ok: false, message: 'Bluetooth is off — turn it on and try again');
      }

      await DeviceStore.instance.load();
      final paired = DeviceStore.instance.cached;
      final su = paired?.bleServiceUuid?.trim();
      final serviceStr = (su != null && su.isNotEmpty) ? su : BleMyFrameDefaults.serviceUuid;
      final du = paired?.bleDataCharUuid?.trim();
      final dataStr = (du != null && du.isNotEmpty) ? du : BleMyFrameDefaults.dataCharUuid;
      final np = paired?.bleNamePrefix?.trim();
      final namePrefix = (np != null && np.isNotEmpty) ? np : BleMyFrameDefaults.defaultNamePrefix;

      final fingerprint = '$serviceStr|$dataStr|${paired?.deviceId ?? ''}';
      if (fingerprint != _sessionFingerprint) {
        await _disconnectAndClear(emit: true);
      }
      _sessionFingerprint = fingerprint;

      _emitConnection(FrameConnectionState.connecting);

      final serviceGuid = Guid(serviceStr);
      final dataGuid = Guid(dataStr);

      await _ensureSession(serviceGuid: serviceGuid, dataGuid: dataGuid, namePrefix: namePrefix);
      if (_dataChar == null) {
        return SendResult(
          ok: false,
          message: 'MyFrame BLE service/characteristic not found (check firmware UUIDs or pairing QR)',
        );
      }

      _emitConnection(FrameConnectionState.connected);
      await _writeAllBytes(_dataChar!, bytes);

      if (kDebugMode) {
        debugPrint(
          '[MyFrame] BLE sent ${bytes.length}B file=$filename slideshow=${slideshow.apiValue} (session kept)',
        );
      }
      return SendResult(ok: true, message: 'Sent ${bytes.length} bytes over BLE');
    } on TimeoutException catch (e) {
      return SendResult(ok: false, message: e.message ?? e.toString());
    } catch (e) {
      return SendResult(ok: false, message: e.toString());
    }
    // On success, GATT stays up for the next image. We do not tear down on send failure
    // (user can retry on the same link) except when [releaseSession] is used, the link is
    // lost, or the paired device id / BLE uuids (fingerprint) change.
  }

  Future<void> _ensureSession({
    required Guid serviceGuid,
    required Guid dataGuid,
    required String namePrefix,
  }) async {
    if (_device != null && _device!.isConnected && _dataChar != null) {
      return;
    }
    if (_device != null && (!_device!.isConnected || _dataChar == null)) {
      await _disconnectAndClear(emit: true);
    }

    final device = await _scanAndPickDevice(serviceGuid, namePrefix);
    if (Platform.isAndroid) {
      await device.connect(
        timeout: const Duration(seconds: 25),
        mtu: 512,
      );
    } else {
      await device.connect(timeout: const Duration(seconds: 25));
    }

    final services = await device.discoverServices(timeout: 25);
    final dataChar = _findDataCharacteristic(services, serviceGuid, dataGuid);
    if (dataChar == null) {
      try {
        await device.disconnect();
      } catch (_) {}
      return;
    }

    _device = device;
    _dataChar = dataChar;
    await _linkSub?.cancel();
    _linkSub = _device!.connectionState.listen((s) {
      if (s == BluetoothConnectionState.disconnected) {
        unawaited(_onPeripheralDisconnect());
      }
    });
  }

  Future<void> _onPeripheralDisconnect() async {
    if (kDebugMode) debugPrint('[MyFrame] BLE link dropped (peripheral or range)');
    await _disconnectAndClear(emit: true);
    _sessionFingerprint = null;
  }

  /// Clears the session and optional Bluetooth disconnect; [emit] controls whether a disconnected event is added.
  Future<void> _disconnectAndClear({bool emit = true}) async {
    await _linkSub?.cancel();
    _linkSub = null;
    _dataChar = null;
    final d = _device;
    _device = null;
    if (d != null) {
      try {
        if (d.isConnected) {
          await d.disconnect();
        }
      } catch (_) {}
    }
    if (emit) {
      _emitConnection(FrameConnectionState.disconnected);
    }
  }

  /// Picks the first advertisement that includes [serviceGuid] and optional name prefix.
  Future<BluetoothDevice> _scanAndPickDevice(Guid serviceGuid, String namePrefix) async {
    final completer = Completer<BluetoothDevice>();
    late final StreamSubscription<List<ScanResult>> sub;
    var done = false;

    void tryComplete(List<ScanResult> results) {
      if (done) return;
      for (final r in results) {
        final name = r.device.advName;
        final matchName = namePrefix.isEmpty ||
            name.toLowerCase().contains(namePrefix.toLowerCase()) ||
            name.isEmpty;
        if (!matchName) continue;
        done = true;
        if (!completer.isCompleted) {
          completer.complete(r.device);
        }
        unawaited(FlutterBluePlus.stopScan());
        return;
      }
    }

    sub = FlutterBluePlus.scanResults.listen(tryComplete);

    try {
      unawaited(
        FlutterBluePlus.startScan(
          withServices: [serviceGuid],
          timeout: const Duration(seconds: 22),
          androidUsesFineLocation: Platform.isAndroid,
        ),
      );
      return await completer.future.timeout(
        const Duration(seconds: 24),
        onTimeout: () => throw TimeoutException(
          'No MyFrame BLE found (frame may keep BLE off when on Wi‑Fi). '
          'For VPS/cloud send: scan the pairing QR so API URL + token are saved, '
          'then choose Wi‑Fi (not Bluetooth-only) in the editor.',
        ),
      );
    } finally {
      try {
        await FlutterBluePlus.stopScan();
      } catch (_) {}
      await sub.cancel();
    }
  }

  BluetoothCharacteristic? _findDataCharacteristic(
    List<BluetoothService> services,
    Guid serviceGuid,
    Guid dataGuid,
  ) {
    for (final s in services) {
      if (s.uuid != serviceGuid) continue;
      for (final c in s.characteristics) {
        if (c.uuid == dataGuid &&
            (c.properties.write || c.properties.writeWithoutResponse)) {
          return c;
        }
      }
    }
    for (final s in services) {
      for (final c in s.characteristics) {
        if (c.uuid == dataGuid &&
            (c.properties.write || c.properties.writeWithoutResponse)) {
          return c;
        }
      }
    }
    return null;
  }

  Future<void> _writeAllBytes(BluetoothCharacteristic char, List<int> raw) async {
    final total = raw.length;
    final header = ByteData(4)..setUint32(0, total, Endian.big);
    final headerBytes = header.buffer.asUint8List();

    final useNoResponse = char.properties.writeWithoutResponse;
    await _writeChunk(char, headerBytes, preferNoResponse: useNoResponse);

    var offset = 0;
    while (offset < total) {
      final end = (offset + BleMyFrameDefaults.maxChunkWithResponse < total)
          ? offset + BleMyFrameDefaults.maxChunkWithResponse
          : total;
      final chunk = Uint8List.fromList(raw.sublist(offset, end));
      await _writeChunk(char, chunk, preferNoResponse: useNoResponse);
      offset = end;
    }
  }

  Future<void> _writeChunk(
    BluetoothCharacteristic char,
    Uint8List data, {
    required bool preferNoResponse,
  }) async {
    if (preferNoResponse && char.properties.writeWithoutResponse) {
      await char.write(data, withoutResponse: true);
    } else if (char.properties.write) {
      await char.write(data, withoutResponse: false);
    } else if (char.properties.writeWithoutResponse) {
      await char.write(data, withoutResponse: true);
    } else {
      throw StateError('Characteristic is not writable');
    }
  }

}
