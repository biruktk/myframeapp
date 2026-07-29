import 'dart:async';
import 'dart:convert';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'ble_frame_scan_filter.dart';
import 'ble_permissions_util.dart';
import 'device_store.dart';
import 'frame_mac_util.dart';
import 'app_diag_log.dart';

class BlufiProvisionResult {
  const BlufiProvisionResult({
    required this.ok,
    required this.message,
    this.confirmed = false,
  });
  final bool ok;
  final String message;
  final bool confirmed;
}

/// After Wi‑Fi, optional `mqtt_config` JSON (`host`, `port`, `usr`, `pwd` in `data`).
class SelfHostedMqttConfig {
  const SelfHostedMqttConfig({
    required this.host,
    this.port = 1883,
    this.httpPort = 80,
    this.user = '',
    this.password = '',
  });
  final String host;
  final int port;

  /// HTTP port for MYFM `.bin` download in MQTT `play` (VPS Nginx :80).
  final int httpPort;
  final String user;
  final String password;
}

class BlufiProvisioningService {
  BlufiProvisioningService._();
  static final BlufiProvisioningService instance = BlufiProvisioningService._();
  static const _defaultFrameServiceUuid =
      '0000ffff-0000-1000-8000-00805f9b34fb';
  static const _defaultFrameDataUuid = '0000ff01-0000-1000-8000-00805f9b34fb';
  static const _defaultFrameNotifyUuid = '0000ff02-0000-1000-8000-00805f9b34fb';

  /// Secondary BLE peripheral on some XT-style frames (Wi‑Fi / control channel).
  static const _vendorServiceUuid = '00002760-08c2-11e1-9073-0e8ac72e1001';
  static const _vendorWriteUuid = '00002760-08c2-11e1-9073-0e8ac72e0001';
  static const _vendorNotifyUuid = '00002760-08c2-11e1-9073-0e8ac72e0002';
  static const _opModeSta = 0x01;

  /// EspBlufi app sends custom JSON as BluFi DATA + CUSTOM_DATA (0x13), not raw GATT bytes.
  static const _blufiSubtypeCustomData = 0x13;
  static const _mqttBeforeWifiDelay = Duration(milliseconds: 800);

  void _d(String m) => AppDiagLog.verbose('[BluFi] $m');

  Future<BlufiProvisionResult> provision({
    required PairedFrame paired,
    required String ssid,
    required String password,
    SelfHostedMqttConfig? selfHostedMqtt,

    /// True when [reconfigureServer] already sent mqtt_config in a prior BLE session.
    bool serverConfigAlreadySent = false,
  }) async {
    try {
      _d(
        'provision start ssid="$ssid" pwdLen=${password.length} '
        'pairedDeviceId=${paired.deviceId} bleRemoteId=${paired.bleRemoteId} '
        'bleNamePrefix=${paired.bleNamePrefix} bleService=${paired.bleServiceUuid} bleData=${paired.bleDataCharUuid}',
      );
      final granted = await _ensurePerms();
      if (!granted) {
        _d('abort: Bluetooth permission denied');
        return const BlufiProvisionResult(
          ok: false,
          message: 'Bluetooth permission denied',
        );
      }
      if (!await FlutterBluePlus.isSupported) {
        _d('abort: BLE not supported');
        return const BlufiProvisionResult(
          ok: false,
          message: 'Bluetooth LE not supported',
        );
      }
      final adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        _d('abort: Bluetooth adapter off');
        return const BlufiProvisionResult(
          ok: false,
          message: 'Bluetooth is off',
        );
      }
      // Ensure no stale scan session competes with GATT provisioning.
      try {
        await FlutterBluePlus.stopScan();
        _d('pre-provision: stopped active BLE scan');
      } catch (_) {}

      final candidates = await _scanProvisionCandidates(paired);
      if (candidates.isEmpty) {
        _d('abort: scan finished with zero BLE candidates');
        return const BlufiProvisionResult(
          ok: false,
          message:
              'No frame found over Bluetooth. Turn it on, stay close, and try again (names like IJ_…, ink_joy…, or 3837… companion).',
        );
      }
      for (var i = 0; i < candidates.length; i++) {
        final d = candidates[i];
        _d(
          'candidate[${i + 1}/${candidates.length}] remoteId=${d.remoteId.str} '
          'advName="${d.advName}" platformName="${d.platformName}"',
        );
      }

      Object? lastFailure;
      StackTrace? lastStack;
      var wroteWifiWithoutAck = false;
      for (var ci = 0; ci < candidates.length; ci++) {
        final remote = candidates[ci];
        try {
          await _connectWithRetry(remote);
          _d('connected state=${remote.isConnected} mtu=${remote.mtuNow}');
          _d('discoverServices (timeout 12s)…');
          var services = await remote.discoverServices(timeout: 12);
          _d(
            'discovered ${services.length} primary service(s): '
            '${services.map((s) => s.uuid.str).join(", ")}',
          );
          var picked = _pickProvisionGatt(services, paired);
          if (picked == null) {
            _d(
              'no provisioning write char on ${remote.remoteId.str} — try next candidate',
            );
            await remote.disconnect();
            _d('disconnected (skipped candidate)');
            continue;
          }
          _d(
            'using write=${picked.write.uuid.str} notify=${picked.notifyGuid.str} '
            'writeProps w=${picked.write.properties.write} wNoResp=${picked.write.properties.writeWithoutResponse}',
          );

          final sendMqttFirst =
              !serverConfigAlreadySent &&
              selfHostedMqtt != null &&
              selfHostedMqtt.host.trim().isNotEmpty;
          int? blufiStaStartSeq;
          if (sendMqttFirst) {
            final mqtt = selfHostedMqtt;
            _d(
              'mqtt_config BEFORE Wi‑Fi (EspBlufi order) → '
              '${mqtt.host}:${mqtt.port}',
            );
            blufiStaStartSeq = await deliverMqttConfig(
              services: services,
              fallbackWrite: picked.write,
              cfg: mqtt,
            );
            await Future<void>.delayed(_mqttBeforeWifiDelay);
          } else if (serverConfigAlreadySent) {
            _d('mqtt_config skipped — already sent in prior BLE session');
          }

          _d('starting BluFi Wi‑Fi provisioning flow');
          var ack = false;
          for (var retry = 1; retry <= 3; retry++) {
            if (retry > 1) {
              _d('wi‑fi send retry=$retry — reconnecting');
              await Future<void>.delayed(const Duration(seconds: 1) * retry);
              try {
                await remote.disconnect();
              } catch (_) {}
              await _connectWithRetry(remote);
              final s = await remote.discoverServices(timeout: 12);
              final p = _pickProvisionGatt(s, paired);
              if (p == null) break;
              picked = p;
              services = s;
              if (sendMqttFirst) {
                blufiStaStartSeq = await deliverMqttConfig(
                  services: services,
                  fallbackWrite: picked!.write,
                  cfg: selfHostedMqtt!,
                );
              }
            }
            ack = await _sendBlufiStaFrames(
              writeChar: picked!.write,
              services: services,
              preferredNotify: picked!.notifyGuid,
              ssid: ssid,
              password: password,
              startSeq: blufiStaStartSeq,
            );
            if (ack) break;
            _d('wi‑fi send attempt $retry failed, retrying…');
          }
          // EspBluFi order: mqtt_config only before Wi‑Fi (scan / manual config session), never after STA connect.
          if (ack && serverConfigAlreadySent) {
            _d(
              'mqtt_config skipped after Wi‑Fi — already sent in prior BLE session',
            );
          } else if (ack && sendMqttFirst) {
            _d(
              'mqtt_config already sent before Wi‑Fi in this session (EspBluFi order)',
            );
          }
          if (ack) {
            await _rememberBleIdentity(paired: paired, remote: remote);
          }
          await remote.disconnect();
          _d('disconnected after candidate[${ci + 1}] ack=$ack');
          if (ack) {
            return const BlufiProvisionResult(
              ok: true,
              confirmed: true,
              message: 'Frame confirmed Wi-Fi connection',
            );
          }
          wroteWifiWithoutAck = true;
          _d(
            'no ack from ${remote.remoteId.str} — trying next candidate if any',
          );
        } catch (e, st) {
          lastFailure = e;
          lastStack = st;
          _d('candidate[${ci + 1}] ${remote.remoteId.str} ERROR: $e');
          _d('stack: $st');
          try {
            await remote.disconnect();
            _d('disconnected after error');
          } catch (e2) {
            _d('disconnect after error failed: $e2');
          }
        }
      }
      if (lastFailure != null) {
        _d('all candidates ended; lastError=$lastFailure');
        if (lastStack != null) _d('lastStack: $lastStack');
        return BlufiProvisionResult(ok: false, message: lastFailure.toString());
      }
      if (wroteWifiWithoutAck) {
        _d(
          'abort: sent Wi-Fi credentials over BluFi but never got firmware ack/confirm',
        );
        return const BlufiProvisionResult(
          ok: false,
          confirmed: false,
          message:
              'The frame did not confirm Wi-Fi over Bluetooth. Check the password, use 2.4 GHz Wi‑Fi if possible, stay close to the frame, and try again.',
        );
      }
      _d('no candidate left with usable GATT');
      return const BlufiProvisionResult(
        ok: false,
        message: 'No usable Wi-Fi provisioning channel on nearby BLE devices.',
      );
    } catch (e, st) {
      _d('provision fatal: $e');
      _d('stack: $st');
      return BlufiProvisionResult(ok: false, message: e.toString());
    }
  }

  Future<BlufiProvisionResult> reconfigureServer({
    required PairedFrame paired,
    required SelfHostedMqttConfig selfHostedMqtt,
  }) async {
    try {
      final granted = await _ensurePerms();
      if (!granted) {
        return const BlufiProvisionResult(
          ok: false,
          message: 'Bluetooth permission denied',
        );
      }
      if (!await FlutterBluePlus.isSupported) {
        return const BlufiProvisionResult(
          ok: false,
          message: 'Bluetooth LE not supported',
        );
      }
      final adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        return const BlufiProvisionResult(
          ok: false,
          message: 'Bluetooth is off',
        );
      }
      try {
        await FlutterBluePlus.stopScan();
      } catch (_) {}
      final candidates = await _scanProvisionCandidates(paired);
      if (candidates.isEmpty) {
        return const BlufiProvisionResult(
          ok: false,
          message:
              'No frame found over Bluetooth. Turn it on, stay close, and try again.',
        );
      }
      Object? lastFailure;
      for (final remote in candidates) {
        try {
          await _connectWithRetry(remote);
          final services = await remote.discoverServices(timeout: 12);
          final picked = _pickProvisionGatt(services, paired);
          if (picked == null) {
            await remote.disconnect();
            continue;
          }
          await deliverMqttConfig(
            services: services,
            fallbackWrite: picked.write,
            cfg: selfHostedMqtt,
          );
          await Future<void>.delayed(const Duration(milliseconds: 500));
          await _rememberBleIdentity(paired: paired, remote: remote);
          await remote.disconnect();
          return const BlufiProvisionResult(
            ok: true,
            confirmed: true,
            message: 'Server configuration sent to frame.',
          );
        } catch (e) {
          lastFailure = e;
          try {
            await remote.disconnect();
          } catch (_) {}
        }
      }
      return BlufiProvisionResult(
        ok: false,
        message:
            lastFailure?.toString() ??
            'Could not reconfigure the frame server.',
      );
    } catch (e) {
      return BlufiProvisionResult(ok: false, message: e.toString());
    }
  }

  Future<void> _rememberBleIdentity({
    required PairedFrame paired,
    required BluetoothDevice remote,
  }) async {
    final remoteId = remote.remoteId.str.trim();
    if (remoteId.isEmpty) return;
    final displayName = remote.advName.trim().isNotEmpty
        ? remote.advName.trim()
        : (remote.platformName.trim().isNotEmpty
              ? remote.platformName.trim()
              : (paired.bleNamePrefix?.trim() ?? ''));
    await DeviceStore.instance.saveManualPairing(
      deviceId: paired.deviceId,
      bleRemoteId: remoteId,
      bleNamePrefix: displayName.isEmpty ? null : displayName,
    );
    final mac = FrameMacUtil.macFromBleIdentity(
      bleName: displayName,
      fallbackText: paired.deviceId,
    );
    if (mac != null) {
      await DeviceStore.instance.savePairedFrameMac(mac);
      _d('saved pairedFrameMac=$mac from BLE name "$displayName"');
    }
    _d(
      'remembered BLE identity deviceId=${paired.deviceId} bleRemoteId=$remoteId name="$displayName"',
    );
  }

  Future<void> _negotiateMtu(BluetoothDevice remote) async {
    try {
      await remote.requestMtu(512);
      _d('MTU negotiated mtuNow=${remote.mtuNow}');
    } catch (e) {
      _d('MTU request failed (non-fatal): $e');
    }
  }

  Future<void> _connectWithRetry(BluetoothDevice remote) async {
    Object? lastError;
    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        _d('connect → ${remote.remoteId.str} attempt=$attempt timeout=14s');
        await remote.connect(timeout: const Duration(seconds: 14));
        await _negotiateMtu(remote);
        return;
      } catch (e) {
        lastError = e;
        _d('connect attempt=$attempt failed: $e');
        try {
          await remote.disconnect();
        } catch (_) {}
        await Future<void>.delayed(Duration(milliseconds: 350 * attempt));
      }
    }
    throw lastError ?? StateError('connect failed');
  }

  Future<bool> _sendBlufiStaFrames({
    required BluetoothCharacteristic writeChar,
    required List<BluetoothService> services,
    required Guid preferredNotify,
    required String ssid,
    required String password,
    int? startSeq,
  }) async {
    var seq = startSeq ?? 0;
    int crc16Esp(List<int> data) {
      var crc = 0xffff;
      for (final b in data) {
        crc ^= (b & 0xff) << 8;
        for (var i = 0; i < 8; i++) {
          if ((crc & 0x8000) != 0) {
            crc = ((crc << 1) ^ 0x1021) & 0xffff;
          } else {
            crc = (crc << 1) & 0xffff;
          }
        }
      }
      return (~crc) & 0xffff;
    }

    Future<void> sendFrame(
      int pkgType,
      int subtype,
      List<int> payload, {
      bool checksum = false,
    }) async {
      final typeSubtype = ((subtype & 0x3f) << 2) | (pkgType & 0x03);
      final frameCtrl = checksum ? 0x02 : 0x00;
      final dataLen = payload.length & 0xff;
      final seqByte = seq & 0xff;
      final frame = <int>[typeSubtype, frameCtrl, seqByte, dataLen, ...payload];
      if (checksum) {
        final toCheck = <int>[seqByte, dataLen, ...payload];
        final crc = crc16Esp(toCheck);
        frame.add(crc & 0xff);
        frame.add((crc >> 8) & 0xff);
      }
      seq++;
      _d(
        'blufi frame pkg=$pkgType subtype=0x${subtype.toRadixString(16)} len=${payload.length} seq=${seq - 1} frameCtrl=0x${frameCtrl.toRadixString(16)}',
      );
      await _writeRaw(writeChar, frame);
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }

    try {
      BluetoothCharacteristic? notifyChar;
      for (final s in services) {
        for (final c in s.characteristics) {
          if (_uuidEqStr(c.uuid.str, preferredNotify.str) &&
              (c.properties.notify || c.properties.indicate)) {
            notifyChar = c;
            break;
          }
        }
        if (notifyChar != null) break;
      }
      final notifyPayloads = <List<int>>[];
      StreamSubscription<List<int>>? notifySub;
      if (notifyChar != null) {
        await notifyChar.setNotifyValue(true);
        notifySub = notifyChar.lastValueStream.listen((p) {
          if (p.isEmpty) return;
          notifyPayloads.add(p);
          _d(
            'blufi notify len=${p.length} hex=${p.map((b) => b.toRadixString(16).padLeft(2, "0")).join(" ")}',
          );
        });
        _d('blufi: subscribed notify before writing');
      }

      // ctrl:set op mode -> STA
      await sendFrame(0x00, 0x02, const [_opModeSta], checksum: false);
      // data: STA ssid
      await sendFrame(0x01, 0x02, utf8.encode(ssid), checksum: false);
      // data: STA password (skip for open networks)
      if (password.isNotEmpty) {
        await sendFrame(0x01, 0x03, utf8.encode(password), checksum: false);
      }
      // ctrl: connect wifi
      await sendFrame(0x00, 0x03, const [], checksum: false);
      // ctrl: query wifi status (some firmwares only answer when queried)
      await sendFrame(0x00, 0x05, const [], checksum: false);
      _d('blufi frames sent, waiting for status report...');
      var ack = false;
      var seenStatusFrame = false;
      var handledNotifyCount = 0;
      final deadline = DateTime.now().add(const Duration(seconds: 25));
      var nextStatusPollAt = DateTime.now().add(const Duration(milliseconds: 1500));
      while (DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        // Mirror EspBlufi behavior by asking status repeatedly until connected.
        if (DateTime.now().isAfter(nextStatusPollAt)) {
          await sendFrame(0x00, 0x05, const [], checksum: false);
          nextStatusPollAt = DateTime.now().add(const Duration(milliseconds: 1500));
        }
        while (handledNotifyCount < notifyPayloads.length) {
          final payload = notifyPayloads[handledNotifyCount++];
          final parsed = _parseBlufiFrame(payload);
          if (parsed == null) continue;
          if (parsed.pkgType == 0x01 &&
              parsed.subtype == 0x0f &&
              parsed.data.length >= 3) {
            seenStatusFrame = true;
            final opMode = parsed.data[0];
            final staState = parsed.data[1];
            final softApConn = parsed.data[2];
            if (staState == 0x00) {
              _d(
                'blufi: Wi-Fi connected with IP confirmed (opMode=0x${opMode.toRadixString(16)} softApConn=$softApConn)',
              );
              ack = true;
              break;
            }
            _d(
              'blufi: status frame opMode=0x${opMode.toRadixString(16)} staState=0x${staState.toRadixString(16)} softApConn=$softApConn',
            );
          }
        }
        if (ack) break;
      }
      await notifySub?.cancel();
      try {
        await notifyChar?.setNotifyValue(false);
      } catch (_) {}
      if (!ack && seenStatusFrame) {
        _d(
          'blufi: status frame(s) received but no connected-with-ip state before timeout',
        );
      }
      _d('blufi ack=$ack');
      return ack;
    } catch (e, st) {
      _d('blufi error: $e');
      _d('blufi stack: $st');
      return false;
    }
  }

  List<int> mqttConfigJsonBytes(SelfHostedMqttConfig cfg) {
    final host = cfg.host.trim();
    return utf8.encode(
      jsonEncode({
        'msgid': DateTime.now().millisecondsSinceEpoch.toString(),
        'action': 'mqtt_config',
        'data': {
          'host': host,
          'port': cfg.port,
          'usr': cfg.user,
          'pwd': cfg.password,
        },
      }),
    );
  }

  /// Same transport as EspBlufi: BluFi CUSTOM_DATA on FFFF/ff01 when present, else raw vendor JSON.
  Future<int?> deliverMqttConfig({
    required List<BluetoothService> services,
    required BluetoothCharacteristic fallbackWrite,
    required SelfHostedMqttConfig cfg,
  }) async {
    final bytes = mqttConfigJsonBytes(cfg);
    _d('mqtt_config json len=${bytes.length}');
    return deliverConfigJson(
      services: services,
      fallbackWrite: fallbackWrite,
      jsonBytes: bytes,
    );
  }

  Future<int?> deliverConfigJson({
    required List<BluetoothService> services,
    required BluetoothCharacteristic fallbackWrite,
    required List<int> jsonBytes,
  }) async {
    final blufiChar = _findBlufiDataChar(services);
    if (blufiChar != null) {
      _d(
        'config via BluFi CUSTOM_DATA (0x13) on FFFF/ff01 '
        '(matches EspBlufi mobile app)',
      );
      return _sendBlufiCustomData(blufiChar, jsonBytes);
    }
    _d('config via raw JSON on ${fallbackWrite.uuid.str} (vendor channel)');
    await _writeUtf8Chunks(fallbackWrite, jsonBytes);
    return null;
  }

  BluetoothCharacteristic? _findBlufiDataChar(List<BluetoothService> services) {
    for (final s in services) {
      if (!_uuidEqStr(s.uuid.str, _defaultFrameServiceUuid)) continue;
      for (final c in s.characteristics) {
        if (_uuidEqStr(c.uuid.str, _defaultFrameDataUuid) &&
            (c.properties.write || c.properties.writeWithoutResponse)) {
          return c;
        }
      }
    }
    return null;
  }

  Future<int> _sendBlufiCustomData(
    BluetoothCharacteristic writeChar,
    List<int> bytes,
  ) async {
    const pkgData = 0x01;
    const maxFrameBytes = 20;
    const headerBytes = 4;
    const fragCtrl = 0x10;
    const fragMetaBytes = 2;
    const typeSubtype =
        ((_blufiSubtypeCustomData & 0x3f) << 2) | (pkgData & 0x03);
    final frames = <List<int>>[];
    var offset = 0;
    var seq = 0;
    while (offset < bytes.length) {
      final remaining = bytes.length - offset;
      const finalPayloadMax = maxFrameBytes - headerBytes;
      if (remaining <= finalPayloadMax) {
        final part = bytes.sublist(offset);
        frames.add(<int>[typeSubtype, 0x00, seq & 0xff, part.length, ...part]);
        offset = bytes.length;
      } else {
        const partLen = maxFrameBytes - headerBytes - fragMetaBytes;
        final end = offset + partLen;
        final part = bytes.sublist(offset, end);
        // BluFi fragment header: total length is the full CUSTOM_DATA payload, not remaining bytes.
        final totalContentLen = bytes.length;
        final dataLen = part.length + fragMetaBytes;
        if (totalContentLen < part.length ||
            dataLen > maxFrameBytes - headerBytes) {
          throw StateError(
            'Invalid BluFi fragment length: total=$totalContentLen part=${part.length}',
          );
        }
        frames.add(<int>[
          typeSubtype,
          fragCtrl,
          seq & 0xff,
          dataLen,
          totalContentLen & 0xff,
          (totalContentLen >> 8) & 0xff,
          ...part,
        ]);
        offset = end;
      }
      seq += 1;
    }
    _d(
      'blufi custom data fragmented len=${bytes.length} frames=${frames.length} json="${utf8.decode(bytes)}"',
    );
    for (final frame in frames) {
      if ((frame[1] & fragCtrl) != 0) {
        final declaredTotal = frame[4] | (frame[5] << 8);
        final contentLen = frame[3] - fragMetaBytes;
        _d(
          'blufi custom fragment seq=${frame[2]} declaredTotal=$declaredTotal contentLen=$contentLen rawLen=${frame.length}',
        );
      }
      await _writeRaw(writeChar, frame);
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
    await Future<void>.delayed(const Duration(milliseconds: 800));
    return frames.length;
  }

  Future<void> _writeUtf8Chunks(
    BluetoothCharacteristic c,
    List<int> bytes,
  ) async {
    const chunk = 180;
    for (var i = 0; i < bytes.length; i += chunk) {
      final end = i + chunk < bytes.length ? i + chunk : bytes.length;
      final part = bytes.sublist(i, end);
      if (c.properties.write) {
        await c.write(part, withoutResponse: false);
      } else if (c.properties.writeWithoutResponse) {
        await c.write(part, withoutResponse: true);
      } else {
        throw StateError('Characteristic has no write mode');
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }

  Future<void> _writeRaw(BluetoothCharacteristic c, List<int> bytes) async {
    final useNoResp = !c.properties.write && c.properties.writeWithoutResponse;
    AppDiagLog.verbose(
      '[BluFi] raw write len=${bytes.length} withoutResponse=$useNoResp',
    );
    if (c.properties.write) {
      await c.write(bytes, withoutResponse: false);
    } else if (c.properties.writeWithoutResponse) {
      await c.write(bytes, withoutResponse: true);
    } else {
      throw StateError('Characteristic has no write mode');
    }
  }

  Future<bool> _ensurePerms() async {
    return ensureBlePermissionsBeforeScan();
  }

  /// Order: paired / IJ_ primary first, then 3837 companion.
  Future<List<BluetoothDevice>> _scanProvisionCandidates(PairedFrame p) async {
    final rid = p.bleRemoteId?.trim();
    if (rid != null && rid.isNotEmpty) {
      _d('bleRemoteId=$rid known — connecting directly, skipping 30s scan');
      return [BluetoothDevice.fromId(rid)];
    }
    final targetId = p.bleRemoteId?.trim();
    final normTargetId = _normalizeBleId(targetId);
    final targetPrefix = (p.bleNamePrefix ?? 'IJ_').trim().toLowerCase();
    const companionPrefix = '3837';
    _d(
      'scan start 30s match: normBleId="$normTargetId" namePrefix="$targetPrefix" companionPrefix=$companionPrefix',
    );

    final companionOrder = <String>[];
    final primaryOrder = <String>[];
    final companionById = <String, BluetoothDevice>{};
    final primaryById = <String, BluetoothDevice>{};

    late final StreamSubscription<List<ScanResult>> sub;
    sub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        final rid = r.device.remoteId.str.trim();
        final normRid = _normalizeBleId(rid);
        final rawName = r.advertisementData.advName.trim().isNotEmpty
            ? r.advertisementData.advName
            : (r.device.platformName.trim().isNotEmpty
                  ? r.device.platformName
                  : r.device.advName);
        final nameLower = rawName.toLowerCase();
        final idOk = normTargetId.isNotEmpty && normRid == normTargetId;
        final discoverable = BleFrameScanFilter.isDiscoverableEntry(
          effectiveName: rawName.trim(),
          serviceUuids: r.advertisementData.serviceUuids,
          nativeServiceUuidStrings: null,
        );
        final nameOk =
            targetPrefix.isNotEmpty && nameLower.contains(targetPrefix);
        if (nameLower.startsWith(companionPrefix)) {
          companionById[rid] = r.device;
          if (!companionOrder.contains(rid)) companionOrder.add(rid);
        }
        if (idOk || discoverable || nameOk) {
          primaryById[rid] = r.device;
          if (!primaryOrder.contains(rid)) primaryOrder.add(rid);

          AppDiagLog.verbose('[BluFi] scan primary id=$rid name=$rawName');
        }
        if (nameLower.startsWith(companionPrefix)) {
          _d('scan hit companion id=$rid advName="$rawName"');
        }
      }
    });
    try {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 30),
        androidUsesFineLocation: true,
        androidScanMode: AndroidScanMode.lowLatency,
        continuousUpdates: false,
      );
      await Future<void>.delayed(const Duration(seconds: 30));
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('scanning too frequently') || msg.contains('status=6')) {
        _d(
          'scan throttled by Android (status=6) — using paired device id fallback',
        );
        final rid = p.bleRemoteId?.trim();
        if (rid != null && rid.isNotEmpty) {
          return [BluetoothDevice.fromId(rid)];
        }
      }
      rethrow;
    } finally {
      await FlutterBluePlus.stopScan();
      await sub.cancel();
    }

    final ordered = <BluetoothDevice>[];
    final seen = <String>{};
    void addOrdered(BluetoothDevice? d) {
      if (d == null) return;
      final id = d.remoteId.str;
      if (seen.contains(id)) return;
      seen.add(id);
      ordered.add(d);
    }

    for (final id in primaryOrder) {
      addOrdered(primaryById[id]);
    }
    for (final id in companionOrder) {
      addOrdered(companionById[id]);
    }
    _d(
      'scan done companions=${companionOrder.length} primary=${primaryOrder.length} '
      'orderedCandidates=${ordered.length} (order: primary IJ_/MAC first, then 3837 companion)',
    );
    return ordered;
  }

  /// Resolves write + notify UUIDs: FFFF / QR overrides first, then vendor `2760`, then any custom writable.
  ({BluetoothCharacteristic write, Guid notifyGuid})? _pickProvisionGatt(
    List<BluetoothService> services,
    PairedFrame paired,
  ) {
    final svcStr = paired.bleServiceUuid ?? _defaultFrameServiceUuid;
    final dataStr = paired.bleDataCharUuid ?? _defaultFrameDataUuid;
    BluetoothCharacteristic? w;
    for (final s in services) {
      if (!_uuidEqStr(s.uuid.str, svcStr)) continue;
      for (final c in s.characteristics) {
        if (_uuidEqStr(c.uuid.str, dataStr) &&
            (c.properties.write || c.properties.writeWithoutResponse)) {
          w = c;
          break;
        }
      }
      if (w != null) break;
    }
    if (w != null) {
      _d('GATT pick: FFFF service=$svcStr data=$dataStr');
      return (write: w, notifyGuid: Guid(_defaultFrameNotifyUuid));
    }

    for (final s in services) {
      if (!_uuidEqStr(s.uuid.str, _vendorServiceUuid)) continue;
      BluetoothCharacteristic? vendorWrite;
      BluetoothCharacteristic? vendorNotify;
      for (final c in s.characteristics) {
        if (_uuidEqStr(c.uuid.str, _vendorWriteUuid) &&
            (c.properties.write || c.properties.writeWithoutResponse)) {
          vendorWrite = c;
        }
        if (_uuidEqStr(c.uuid.str, _vendorNotifyUuid) &&
            (c.properties.notify || c.properties.indicate)) {
          vendorNotify = c;
        }
      }
      if (vendorWrite != null) {
        _d('GATT pick: vendor service $_vendorServiceUuid');
        return (
          write: vendorWrite,
          notifyGuid: vendorNotify?.uuid ?? Guid(_vendorNotifyUuid),
        );
      }
    }

    final fallback = _findCustomWritable(services);
    if (fallback != null) {
      var notifyGuid = Guid(_defaultFrameNotifyUuid);
      outer:
      for (final s in services) {
        for (final c in s.characteristics) {
          if (_uuidEqStr(c.uuid.str, fallback.uuid.str)) continue;
          if ((c.properties.notify || c.properties.indicate) &&
              !_isSigAdoptedCharacteristic(c.uuid.str)) {
            notifyGuid = c.uuid;
            break outer;
          }
        }
      }
      _d(
        'GATT pick: fallback custom writable=${fallback.uuid.str} notify=${notifyGuid.str}',
      );
      return (write: fallback, notifyGuid: notifyGuid);
    }
    _d('GATT pick: none (no vendor, no FFFF pair, no custom writable)');
    return null;
  }

  static const _btBaseSuffix = '00001000800000805f9b34fb';

  String _uuidNorm(String uuidStr) {
    final u = uuidStr.toLowerCase().replaceAll('-', '');
    if (u.length == 4) return u;
    if (u.length == 32 && u.endsWith(_btBaseSuffix)) {
      return u.substring(4, 8);
    }
    return u;
  }

  bool _uuidEqStr(String a, String b) => _uuidNorm(a) == _uuidNorm(b);

  String _normalizeBleId(String? raw) {
    if (raw == null) return '';
    return raw.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
  }

  BluetoothCharacteristic? _findCustomWritable(
    List<BluetoothService> services,
  ) {
    for (final s in services) {
      if (_isSigAdoptedService(s.uuid.str)) continue;
      for (final c in s.characteristics) {
        if (_isSigAdoptedCharacteristic(c.uuid.str)) continue;
        if (c.properties.write || c.properties.writeWithoutResponse) {
          return c;
        }
      }
    }
    return null;
  }

  bool _isSigAdoptedService(String uuid) {
    final u = _uuidNorm(uuid);
    // Standard adopted services are in the 0x18xx range under Bluetooth base UUID.
    return RegExp(
      r'^(18[0-9a-f]{2}|000018[0-9a-f]{2}00001000800000805f9b34fb)$',
    ).hasMatch(u);
  }

  bool _isSigAdoptedCharacteristic(String uuid) {
    final u = _uuidNorm(uuid);
    // Standard adopted characteristics are in 0x2Axx / 0x2Bxx ranges.
    return RegExp(
      r'^(2[ab][0-9a-f]{2}|00002[ab][0-9a-f]{2}00001000800000805f9b34fb)$',
    ).hasMatch(u);
  }

  ({int pkgType, int subtype, List<int> data})? _parseBlufiFrame(
    List<int> payload,
  ) {
    if (payload.length < 4) return null;
    final typeSubtype = payload[0] & 0xff;
    final pkgType = typeSubtype & 0x03;
    final subtype = (typeSubtype >> 2) & 0x3f;
    final frameCtrl = payload[1] & 0xff;
    final dataLen = payload[3] & 0xff;
    final hasChecksum = (frameCtrl & 0x02) != 0;
    final requiredLen = 4 + dataLen + (hasChecksum ? 2 : 0);
    if (payload.length < requiredLen) return null;
    final data = payload.sublist(4, 4 + dataLen);
    return (pkgType: pkgType, subtype: subtype, data: data);
  }
}
