import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'wifi_credential_cache.dart';

import '../config/api_config.dart';
import '../config/vps_defaults.dart';
import '../l10n/app_strings.dart';
import '../models/pairing_payload.dart';
import 'frame_mac_util.dart';

/// Persisted pairing(s): multiple frames in JSON + legacy keys mirroring the **active** frame.
class DeviceStore {
  DeviceStore._();

  static final DeviceStore instance = DeviceStore._();

  /// Bumped when paired frames are added, removed, or cleared — Home listens to refresh.
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  void _bumpRevision() => revision.value++;

  static const _kFramesJson = 'paired_frames_json_v1';
  static const _kActiveDeviceId = 'paired_active_device_id_v1';

  static const _kDeviceId = 'paired_device_id';
  static const _kToken = 'paired_pairing_token';
  static const _kApiUrl = 'paired_api_url';
  static const _kBleService = 'paired_ble_service_uuid';
  static const _kBleData = 'paired_ble_data_char_uuid';
  static const _kBleNamePrefix = 'paired_ble_name_prefix';
  static const _kBleRemoteId = 'paired_ble_remote_id';
  static const _kProduct = 'paired_product';
  static const _kWifiSsid = 'paired_wifi_ssid';
  static const _kWifiUser = 'paired_wifi_user';
  static const _kWifiPass = 'paired_wifi_pass';
  static const _kWifiProvisionedAt = 'paired_wifi_provisioned_at';
  static const _kFrameName = 'paired_frame_name';
  static const _kFrameOrientation = 'paired_frame_orientation';
  static const _kMqttHost = 'paired_mqtt_host';
  static const _kMqttPort = 'paired_mqtt_port';
  static const _kMqttUser = 'paired_mqtt_user';
  static const _kMqttPass = 'paired_mqtt_pass';

  /// Same key as WeChat mini program (`wx.setStorageSync('pairedFrameMac', mac)`).
  static const kPairedFrameMac = 'pairedFrameMac';

  List<PairedFrame> _frames = [];
  String? _pairedFrameMac;
  String? _activeDeviceId;

  int _indexOf(String deviceId) {
    final t = deviceId.trim();
    return _frames.indexWhere((e) => e.deviceId.trim() == t);
  }

  /// Frames shown on **My Frames** (order preserved).
  List<PairedFrame> get pairedFrames => List.unmodifiable(_frames);

  /// 12-hex MAC from BLE name (`IJ_…`) for `/api/frames/:mac/*` — never hardcode.
  String? get pairedFrameMac => _pairedFrameMac?.trim().isNotEmpty == true
      ? _pairedFrameMac!.trim().toUpperCase()
      : null;

  /// Active frame used by Send, editor, Wi‑Fi setup, etc.
  PairedFrame? get cached {
    if (_frames.isEmpty) return null;
    final id = _activeDeviceId?.trim();
    if (id != null && id.isNotEmpty) {
      for (final f in _frames) {
        if (f.deviceId.trim() == id) return f;
      }
    }
    return _frames.first;
  }

  Future<PairedFrame?> load() async {
    final p = await SharedPreferences.getInstance();
    final rawMac = p.getString(kPairedFrameMac)?.trim();
    if (rawMac != null && rawMac.isNotEmpty) {
      final bare = rawMac.replaceAll(RegExp(r'[^0-9a-fA-F]'), '').toUpperCase();
      if (bare.length >= 12) {
        final twelve = bare.length == 12 ? bare : bare.substring(bare.length - 12);
        final fixed = PairedFrame.preferEsp32WifiStationMac(twelve) ?? twelve;
        _pairedFrameMac = fixed;
        if (fixed != twelve) {
          await p.setString(kPairedFrameMac, fixed);
        }
      }
    }
    final bundle = p.getString(_kFramesJson);
    if (bundle != null && bundle.isNotEmpty) {
      try {
        final decoded = jsonDecode(bundle);
        if (decoded is List && decoded.isNotEmpty) {
          _frames = decoded
              .map(
                (e) =>
                    PairedFrame.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList();
          _activeDeviceId = p.getString(_kActiveDeviceId)?.trim();
          if (_activeDeviceId == null ||
              _activeDeviceId!.isEmpty ||
              _indexOf(_activeDeviceId!) < 0) {
            _activeDeviceId = _frames.first.deviceId;
          }
          final a = cached;
          if (a != null) await _writeLegacyFromFrame(p, a);
          return a;
        }
      } catch (_) {
        _frames = [];
        _activeDeviceId = null;
      }
    }

    final id = p.getString(_kDeviceId);
    if (id == null || id.isEmpty) {
      _frames = [];
      _activeDeviceId = null;
      return null;
    }
    final f = _readLegacyAsFrame(p, id);
    _frames = [f];
    _activeDeviceId = id;
    await p.setString(
      _kFramesJson,
      jsonEncode(_frames.map((e) => e.toJson()).toList()),
    );
    await p.setString(_kActiveDeviceId, id);
    return cached;
  }

  PairedFrame _readLegacyAsFrame(SharedPreferences p, String id) {
    final mqttPort = p.getInt(_kMqttPort);
    return PairedFrame(
      deviceId: id,
      pairingToken: p.getString(_kToken),
      apiUrl: p.getString(_kApiUrl),
      bleServiceUuid: p.getString(_kBleService),
      bleDataCharUuid: p.getString(_kBleData),
      bleNamePrefix: p.getString(_kBleNamePrefix),
      bleRemoteId: p.getString(_kBleRemoteId),
      product: p.getString(_kProduct),
      wifiSsid: p.getString(_kWifiSsid),
      wifiUsername: p.getString(_kWifiUser),
      wifiPassword: p.getString(_kWifiPass),
      wifiProvisionedAtMs: p.getInt(_kWifiProvisionedAt),
      frameName: p.getString(_kFrameName),
      frameOrientation: p.getString(_kFrameOrientation),
      mqttBrokerHost: p.getString(_kMqttHost),
      mqttBrokerPort: (mqttPort != null && mqttPort > 0) ? mqttPort : null,
      mqttBrokerUser: p.getString(_kMqttUser),
      mqttBrokerPassword: p.getString(_kMqttPass),
    );
  }

  Future<void> setActiveFrameDeviceId(String deviceId) async {
    await load();
    final id = deviceId.trim();
    if (id.isEmpty || _indexOf(id) < 0) return;
    _activeDeviceId = id;
    final p = await SharedPreferences.getInstance();
    await p.setString(_kActiveDeviceId, id);
    final a = cached;
    if (a != null) await _writeLegacyFromFrame(p, a);
  }

  /// Removes one frame and all persisted data tied to it (slideshow, MAC, legacy keys).
  Future<void> forgetPairedFrame(String deviceId) async {
    await load();
    final id = deviceId.trim();
    if (id.isEmpty) return;

    PairedFrame? removed;
    for (final f in _frames) {
      if (f.deviceId.trim() == id) {
        removed = f;
        break;
      }
    }
    if (removed == null) return;

    final p = await SharedPreferences.getInstance();
    await p.remove(_slideshowPrefsKey(_macSlugForFrame(removed)));

    _frames.removeWhere((e) => e.deviceId.trim() == id);

    if (_frames.isEmpty) {
      await clear();
      return;
    }

    if (_activeDeviceId == null ||
        _activeDeviceId!.trim() == id ||
        _indexOf(_activeDeviceId!) < 0) {
      _activeDeviceId = _frames.first.deviceId;
    }

    final active = cached;
    if (active != null) {
      final mac = FrameMacUtil.macFromBleIdentity(
        bleName: active.bleNamePrefix,
        fallbackText: active.deviceId,
      );
      if (mac != null) {
        await savePairedFrameMac(mac);
      } else {
        _pairedFrameMac = null;
        await p.remove(kPairedFrameMac);
      }
    } else {
      _pairedFrameMac = null;
      await p.remove(kPairedFrameMac);
    }

    await _persistAll();
    _bumpRevision();
  }

  Future<void> removePairedFrame(String deviceId) =>
      forgetPairedFrame(deviceId);

  static String _slideshowPrefsKey(String macSlug) =>
      'slideshow_playlist_$macSlug';

  String _macSlugForFrame(PairedFrame f) {
    if (_pairedFrameMac != null && _pairedFrameMac!.length == 12) {
      return _pairedFrameMac!;
    }
    return FrameMacUtil.normalizeSlug(f.resolvedFrameTargetId) ??
        f.deviceId.replaceAll(RegExp(r'[^\w\-]'), 'FRAME');
  }

  Future<void> saveFromPayload(PairingPayload payload) async {
    await load();
    final rawId = payload.deviceId.trim();
    if (rawId.isEmpty) return;
    final id = PairedFrame.preferEsp32WifiStationMac(rawId) ?? rawId;
    final idx = _indexOf(id);
    final old = idx >= 0 ? _frames[idx] : null;
    final merged = PairedFrame(
      deviceId: id,
      pairingToken: payload.pairingToken ?? old?.pairingToken,
      apiUrl: payload.apiUrl ?? old?.apiUrl,
      bleServiceUuid: payload.bleServiceUuid ?? old?.bleServiceUuid,
      bleDataCharUuid: payload.bleDataCharUuid ?? old?.bleDataCharUuid,
      bleNamePrefix: payload.bleNamePrefix ?? old?.bleNamePrefix,
      bleRemoteId: old?.bleRemoteId,
      product: payload.product ?? old?.product,
      wifiSsid: old?.wifiSsid,
      wifiUsername: old?.wifiUsername,
      wifiPassword: old?.wifiPassword,
      wifiProvisionedAtMs: old?.wifiProvisionedAtMs,
      frameName: old?.frameName,
      frameOrientation: old?.frameOrientation,
      mqttBrokerHost: old?.mqttBrokerHost,
      mqttBrokerPort: old?.mqttBrokerPort,
      mqttBrokerUser: old?.mqttBrokerUser,
      mqttBrokerPassword: old?.mqttBrokerPassword,
    );
    if (idx >= 0) {
      _frames[idx] = merged;
    } else {
      _frames.add(merged);
    }
    _activeDeviceId = id;
    final mac = FrameMacUtil.macFromBleIdentity(
      bleName: merged.bleNamePrefix,
      fallbackText: id,
    );
    if (mac != null) await savePairedFrameMac(mac);
    await _persistAll();
  }

  Future<void> savePairedFrameMac(String mac) async {
    final slug = mac.replaceAll(RegExp(r'[^0-9a-fA-F]'), '').toUpperCase();
    if (slug.length < 12) return;
    final bare = slug.length == 12 ? slug : slug.substring(slug.length - 12);
    // MQTT/API use Wi‑Fi station MAC; BLE names often carry BLE MAC (+2).
    final clean = PairedFrame.preferEsp32WifiStationMac(bare) ?? bare;
    _pairedFrameMac = clean;
    final p = await SharedPreferences.getInstance();
    await p.setString(kPairedFrameMac, clean);
  }

  Future<void> saveManualPairing({
    required String deviceId,
    String? bleNamePrefix,
    String? bleRemoteId,
  }) async {
    await load();
    final cleanId = deviceId.trim();
    if (cleanId.isEmpty) return;
    final idx = _indexOf(cleanId);
    final old = idx >= 0 ? _frames[idx] : null;
    final merged = PairedFrame(
      deviceId: cleanId,
      pairingToken: old?.pairingToken,
      apiUrl: old?.apiUrl,
      bleServiceUuid: old?.bleServiceUuid,
      bleDataCharUuid: old?.bleDataCharUuid,
      bleNamePrefix: bleNamePrefix?.trim().isNotEmpty == true
          ? bleNamePrefix!.trim()
          : old?.bleNamePrefix,
      bleRemoteId: bleRemoteId?.trim().isNotEmpty == true
          ? bleRemoteId!.trim()
          : old?.bleRemoteId,
      product: old?.product,
      wifiSsid: old?.wifiSsid,
      wifiUsername: old?.wifiUsername,
      wifiPassword: old?.wifiPassword,
      wifiProvisionedAtMs: old?.wifiProvisionedAtMs,
      frameName: old?.frameName,
      frameOrientation: old?.frameOrientation,
      mqttBrokerHost: old?.mqttBrokerHost,
      mqttBrokerPort: old?.mqttBrokerPort,
      mqttBrokerUser: old?.mqttBrokerUser,
      mqttBrokerPassword: old?.mqttBrokerPassword,
    );
    if (idx >= 0) {
      _frames[idx] = merged;
    } else {
      _frames.add(merged);
    }
    _activeDeviceId = cleanId;
    final mac = FrameMacUtil.macFromBleIdentity(
      bleName: bleNamePrefix,
      fallbackText: cleanId,
    );
    if (mac != null) await savePairedFrameMac(mac);
    await _persistAll();
  }

  Future<void> saveSelfHostedMqtt({
    required String host,
    int port = 1883,
    String user = '',
    String password = '',
  }) async {
    final c = cached;
    if (c == null) return;
    final cleanHost = host.trim();
    final updated = PairedFrame(
      deviceId: c.deviceId,
      pairingToken: c.pairingToken,
      apiUrl: c.apiUrl,
      bleServiceUuid: c.bleServiceUuid,
      bleDataCharUuid: c.bleDataCharUuid,
      bleNamePrefix: c.bleNamePrefix,
      bleRemoteId: c.bleRemoteId,
      product: c.product,
      wifiSsid: c.wifiSsid,
      wifiUsername: c.wifiUsername,
      wifiPassword: c.wifiPassword,
      wifiProvisionedAtMs: c.wifiProvisionedAtMs,
      frameName: c.frameName,
      frameOrientation: c.frameOrientation,
      mqttBrokerHost: cleanHost.isEmpty ? null : cleanHost,
      mqttBrokerPort: cleanHost.isEmpty ? null : port,
      mqttBrokerUser: cleanHost.isEmpty
          ? null
          : (user.trim().isEmpty ? null : user.trim()),
      mqttBrokerPassword: cleanHost.isEmpty
          ? null
          : (password.isEmpty ? null : password),
    );
    _replaceFrame(updated);
    await _persistAll();
  }

  Future<void> saveWifiProvision({
    required String ssid,
    String? username,
    String? password,
  }) async {
    final cleanSsid = normalizeWifiSsid(ssid);
    final cleanUser = username?.trim();
    final cleanPass = password ?? '';
    if (cleanSsid.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final c = cached;
    if (c == null) return;
    final updated = PairedFrame(
      deviceId: c.deviceId,
      pairingToken: c.pairingToken,
      apiUrl: c.apiUrl,
      bleServiceUuid: c.bleServiceUuid,
      bleDataCharUuid: c.bleDataCharUuid,
      bleNamePrefix: c.bleNamePrefix,
      bleRemoteId: c.bleRemoteId,
      product: c.product,
      wifiSsid: cleanSsid,
      wifiUsername: cleanUser,
      wifiPassword: cleanPass.isEmpty ? null : cleanPass,
      wifiProvisionedAtMs: now,
      frameName: c.frameName,
      frameOrientation: c.frameOrientation,
      mqttBrokerHost: c.mqttBrokerHost,
      mqttBrokerPort: c.mqttBrokerPort,
      mqttBrokerUser: c.mqttBrokerUser,
      mqttBrokerPassword: c.mqttBrokerPassword,
    );
    _replaceFrame(updated);
    await _persistAll();
    if (cleanPass.isNotEmpty) {
      await WifiCredentialCache.instance.remember(cleanSsid, cleanPass);
    }
  }

  Future<void> saveFrameProfile({
    required String frameName,
    required String orientation,
  }) async {
    final cleanName = frameName.trim();
    final cleanOrientation = orientation.trim().toLowerCase();
    if (cleanOrientation != 'portrait' && cleanOrientation != 'landscape') {
      return;
    }
    final c = cached;
    if (c == null) return;
    final storedName = cleanName.isEmpty ? null : cleanName;
    final updated = PairedFrame(
      deviceId: c.deviceId,
      pairingToken: c.pairingToken,
      apiUrl: c.apiUrl,
      bleServiceUuid: c.bleServiceUuid,
      bleDataCharUuid: c.bleDataCharUuid,
      bleNamePrefix: c.bleNamePrefix,
      bleRemoteId: c.bleRemoteId,
      product: c.product,
      wifiSsid: c.wifiSsid,
      wifiUsername: c.wifiUsername,
      wifiPassword: c.wifiPassword,
      wifiProvisionedAtMs: c.wifiProvisionedAtMs,
      frameName: storedName,
      frameOrientation: cleanOrientation,
      mqttBrokerHost: c.mqttBrokerHost,
      mqttBrokerPort: c.mqttBrokerPort,
      mqttBrokerUser: c.mqttBrokerUser,
      mqttBrokerPassword: c.mqttBrokerPassword,
    );
    _replaceFrame(updated);
    await _persistAll();
  }

  void _replaceFrame(PairedFrame u) {
    final i = _indexOf(u.deviceId);
    if (i >= 0) _frames[i] = u;
  }

  Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    _frames = [];
    _activeDeviceId = null;
    _pairedFrameMac = null;
    await p.remove(_kFramesJson);
    await p.remove(_kActiveDeviceId);
    await p.remove(kPairedFrameMac);
    await _removeAllLegacy(p);
    _bumpRevision();
  }

  Future<void> _persistAll() async {
    final p = await SharedPreferences.getInstance();
    if (_frames.isEmpty) {
      _activeDeviceId = null;
      await p.remove(_kFramesJson);
      await p.remove(_kActiveDeviceId);
      await _removeAllLegacy(p);
      return;
    }
    await p.setString(
      _kFramesJson,
      jsonEncode(_frames.map((e) => e.toJson()).toList()),
    );
    final a = cached;
    _activeDeviceId = a?.deviceId;
    if (_activeDeviceId != null && _activeDeviceId!.isNotEmpty) {
      await p.setString(_kActiveDeviceId, _activeDeviceId!);
    }
    if (a != null) await _writeLegacyFromFrame(p, a);
  }

  Future<void> _removeAllLegacy(SharedPreferences p) async {
    await p.remove(_kDeviceId);
    await p.remove(_kToken);
    await p.remove(_kApiUrl);
    await p.remove(_kBleService);
    await p.remove(_kBleData);
    await p.remove(_kBleNamePrefix);
    await p.remove(_kBleRemoteId);
    await p.remove(_kProduct);
    await p.remove(_kWifiSsid);
    await p.remove(_kWifiUser);
    await p.remove(_kWifiPass);
    await p.remove(_kWifiProvisionedAt);
    await p.remove(_kFrameName);
    await p.remove(_kFrameOrientation);
    await p.remove(_kMqttHost);
    await p.remove(_kMqttPort);
    await p.remove(_kMqttUser);
    await p.remove(_kMqttPass);
  }

  Future<void> _writeLegacyFromFrame(SharedPreferences p, PairedFrame f) async {
    await p.setString(_kDeviceId, f.deviceId);
    if (f.pairingToken != null && f.pairingToken!.isNotEmpty) {
      await p.setString(_kToken, f.pairingToken!);
    } else {
      await p.remove(_kToken);
    }
    if (f.apiUrl != null && f.apiUrl!.isNotEmpty) {
      await p.setString(_kApiUrl, f.apiUrl!);
    } else {
      await p.remove(_kApiUrl);
    }
    if (f.bleServiceUuid != null && f.bleServiceUuid!.isNotEmpty) {
      await p.setString(_kBleService, f.bleServiceUuid!);
    } else {
      await p.remove(_kBleService);
    }
    if (f.bleDataCharUuid != null && f.bleDataCharUuid!.isNotEmpty) {
      await p.setString(_kBleData, f.bleDataCharUuid!);
    } else {
      await p.remove(_kBleData);
    }
    if (f.bleNamePrefix != null && f.bleNamePrefix!.isNotEmpty) {
      await p.setString(_kBleNamePrefix, f.bleNamePrefix!);
    } else {
      await p.remove(_kBleNamePrefix);
    }
    if (f.bleRemoteId != null && f.bleRemoteId!.isNotEmpty) {
      await p.setString(_kBleRemoteId, f.bleRemoteId!);
    } else {
      await p.remove(_kBleRemoteId);
    }
    if (f.product != null && f.product!.isNotEmpty) {
      await p.setString(_kProduct, f.product!);
    } else {
      await p.remove(_kProduct);
    }
    if (f.wifiSsid != null && f.wifiSsid!.isNotEmpty) {
      await p.setString(_kWifiSsid, f.wifiSsid!);
    } else {
      await p.remove(_kWifiSsid);
    }
    if (f.wifiUsername != null && f.wifiUsername!.isNotEmpty) {
      await p.setString(_kWifiUser, f.wifiUsername!);
    } else {
      await p.remove(_kWifiUser);
    }
    if (f.wifiPassword != null && f.wifiPassword!.isNotEmpty) {
      await p.setString(_kWifiPass, f.wifiPassword!);
    } else {
      await p.remove(_kWifiPass);
    }
    if (f.wifiProvisionedAtMs != null) {
      await p.setInt(_kWifiProvisionedAt, f.wifiProvisionedAtMs!);
    } else {
      await p.remove(_kWifiProvisionedAt);
    }
    if (f.frameName != null && f.frameName!.isNotEmpty) {
      await p.setString(_kFrameName, f.frameName!);
    } else {
      await p.remove(_kFrameName);
    }
    if (f.frameOrientation != null && f.frameOrientation!.isNotEmpty) {
      await p.setString(_kFrameOrientation, f.frameOrientation!);
    } else {
      await p.remove(_kFrameOrientation);
    }
    if (f.mqttBrokerHost != null && f.mqttBrokerHost!.trim().isNotEmpty) {
      await p.setString(_kMqttHost, f.mqttBrokerHost!.trim());
      await p.setInt(_kMqttPort, f.mqttBrokerPort ?? 1883);
      if (f.mqttBrokerUser != null && f.mqttBrokerUser!.isNotEmpty) {
        await p.setString(_kMqttUser, f.mqttBrokerUser!);
      } else {
        await p.remove(_kMqttUser);
      }
      if (f.mqttBrokerPassword != null && f.mqttBrokerPassword!.isNotEmpty) {
        await p.setString(_kMqttPass, f.mqttBrokerPassword!);
      } else {
        await p.remove(_kMqttPass);
      }
    } else {
      await p.remove(_kMqttHost);
      await p.remove(_kMqttPort);
      await p.remove(_kMqttUser);
      await p.remove(_kMqttPass);
    }
  }
}

class PairedFrame {
  const PairedFrame({
    required this.deviceId,
    this.pairingToken,
    this.apiUrl,
    this.bleServiceUuid,
    this.bleDataCharUuid,
    this.bleNamePrefix,
    this.bleRemoteId,
    this.product,
    this.wifiSsid,
    this.wifiUsername,
    this.wifiPassword,
    this.wifiProvisionedAtMs,
    this.frameName,
    this.frameOrientation,
    this.mqttBrokerHost,
    this.mqttBrokerPort,
    this.mqttBrokerUser,
    this.mqttBrokerPassword,
  });

  final String deviceId;
  final String? pairingToken;
  final String? apiUrl;
  final String? bleServiceUuid;
  final String? bleDataCharUuid;
  final String? bleNamePrefix;
  final String? bleRemoteId;
  final String? product;
  final String? wifiSsid;
  final String? wifiUsername;
  final String? wifiPassword;
  final int? wifiProvisionedAtMs;
  final String? frameName;
  final String? frameOrientation;

  final String? mqttBrokerHost;
  final int? mqttBrokerPort;
  final String? mqttBrokerUser;
  final String? mqttBrokerPassword;

  /// Candidate backend targets in priority order (Wi‑Fi / MQTT MAC first).
  ///
  /// ESP32-class frames use BLE MAC = station MAC + 2 (e.g. BLE `…161E`, MQTT
  /// `…161C`). iOS often stores the QR/BLE id plus a CoreBluetooth UUID in
  /// [bleRemoteId]; uploads must target the station MAC, then retry the BLE id.
  List<String> get resolvedFrameTargetCandidates {
    final id = deviceId.trim();
    final ble = bleRemoteId?.trim() ?? '';
    final nameMac = _macFromText(bleNamePrefix ?? '');
    final idMac = _normalizedHexMac(id);
    final bleMac = _normalizedHexMac(ble);
    final out = <String>[];

    void add(String? value) {
      if (value == null) return;
      final v = value.trim().toUpperCase();
      if (v.length != 12 || out.contains(v)) return;
      out.add(v);
    }

    void addEsp32MacFamily(String mac) {
      final bleFromWifi = _esp32BleMacFromWifiMac(mac);
      if (bleFromWifi != null && bleFromWifi != mac) {
        add(mac);
        add(bleFromWifi);
        return;
      }
      final wifiFromBle = _esp32WifiMacFromBleMac(mac);
      if (wifiFromBle != null && wifiFromBle != mac) {
        add(wifiFromBle);
        add(mac);
        return;
      }
      add(mac);
    }

    final seenMacs = <String>{};
    for (final mac in [nameMac, idMac, bleMac]) {
      if (mac == null || !seenMacs.add(mac)) continue;
      addEsp32MacFamily(mac);
    }

    if (out.isEmpty &&
        id.isNotEmpty &&
        !_looksLikeIosPeripheralUuid(id) &&
        !_looksLikeIosPeripheralUuid(ble)) {
      add(id.toUpperCase());
    }
    return out;
  }

  /// Upload targets: station (Wi‑Fi/MQTT) MAC only when it is already known.
  ///
  /// Retrying the BLE (+2) MAC after a timeout publishes to `/inkjoyap/…161E`
  /// where no subscriber exists — Android avoids that; iOS must match.
  List<String> get resolvedFrameUploadTargets {
    final station = resolvedFrameTargetId;
    final all = resolvedFrameTargetCandidates;
    if (all.isEmpty) return const [];
    if (all.length == 1) return all;
    if (all.first == station) return [station];
    return all;
  }

  /// For backend frame commands, target the Wi-Fi/MQTT MAC rather than the BLE MAC.
  String get resolvedFrameTargetId {
    final stored = DeviceStore.instance.pairedFrameMac;
    if (stored != null && stored.isNotEmpty) {
      return preferEsp32WifiStationMac(stored) ?? stored;
    }
    final ids = resolvedFrameTargetCandidates;
    if (ids.isNotEmpty) return ids.first;
    final id = deviceId.trim();
    final ble = bleRemoteId?.trim() ?? '';
    return id.isNotEmpty ? id : ble;
  }

  /// Best-effort Wi‑Fi station MAC for uploads/MQTT from a 12‑hex id (BLE or STA).
  static String? preferEsp32WifiStationMac(String raw) {
    final n = _normalizedHexMac(raw);
    if (n == null) return null;
    final bleFromWifi = _esp32BleMacFromWifiMac(n);
    if (bleFromWifi != null && bleFromWifi != n) return n;
    return _esp32WifiMacFromBleMac(n) ?? n;
  }

  static String? _normalizedHexMac(String raw) {
    final hex = raw.replaceAll(RegExp(r'[^0-9a-fA-F]'), '').toUpperCase();
    if (hex.length != 12) return null;
    return hex;
  }

  static String? _esp32WifiMacFromBleMac(String bleMac) {
    final value = int.tryParse(bleMac, radix: 16);
    if (value == null || value < 2) return null;
    return (value - 2).toRadixString(16).toUpperCase().padLeft(12, '0');
  }

  static String? _esp32BleMacFromWifiMac(String wifiMac) {
    final value = int.tryParse(wifiMac, radix: 16);
    if (value == null) return null;
    final max = (1 << 48) - 1;
    if (value > max - 2) return null;
    return (value + 2).toRadixString(16).toUpperCase().padLeft(12, '0');
  }

  static String? _macFromText(String raw) {
    final upper = raw.toUpperCase();
    if (_looksLikeIosPeripheralUuid(upper)) return null;
    final separated = RegExp(
      r'(?<![0-9A-F])([0-9A-F]{2}[:-]){5}[0-9A-F]{2}(?![0-9A-F])',
    ).firstMatch(upper)?.group(0);
    if (separated != null) {
      return separated.replaceAll(RegExp(r'[^0-9A-F]'), '');
    }
    return RegExp(
      r'(?<![0-9A-F])[0-9A-F]{12}(?![0-9A-F])',
    ).firstMatch(upper)?.group(0);
  }

  static bool _looksLikeIosPeripheralUuid(String raw) {
    return RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(raw.trim());
  }

  Map<String, dynamic> toJson() => {
    'deviceId': deviceId,
    'pairingToken': pairingToken,
    'apiUrl': apiUrl,
    'bleServiceUuid': bleServiceUuid,
    'bleDataCharUuid': bleDataCharUuid,
    'bleNamePrefix': bleNamePrefix,
    'bleRemoteId': bleRemoteId,
    'product': product,
    'wifiSsid': wifiSsid,
    'wifiUsername': wifiUsername,
    'wifiPassword': wifiPassword,
    'wifiProvisionedAtMs': wifiProvisionedAtMs,
    'frameName': frameName,
    'frameOrientation': frameOrientation,
    'mqttBrokerHost': mqttBrokerHost,
    'mqttBrokerPort': mqttBrokerPort,
    'mqttBrokerUser': mqttBrokerUser,
    'mqttBrokerPassword': mqttBrokerPassword,
  };

  factory PairedFrame.fromJson(Map<String, dynamic> m) {
    final port = m['mqttBrokerPort'];
    return PairedFrame(
      deviceId: '${m['deviceId'] ?? ''}'.trim(),
      pairingToken: m['pairingToken'] as String?,
      apiUrl: m['apiUrl'] as String?,
      bleServiceUuid: m['bleServiceUuid'] as String?,
      bleDataCharUuid: m['bleDataCharUuid'] as String?,
      bleNamePrefix: m['bleNamePrefix'] as String?,
      bleRemoteId: m['bleRemoteId'] as String?,
      product: m['product'] as String?,
      wifiSsid: m['wifiSsid'] as String?,
      wifiUsername: m['wifiUsername'] as String?,
      wifiPassword: m['wifiPassword'] as String?,
      wifiProvisionedAtMs: (m['wifiProvisionedAtMs'] as num?)?.toInt(),
      frameName: m['frameName'] as String?,
      frameOrientation: m['frameOrientation'] as String?,
      mqttBrokerHost: m['mqttBrokerHost'] as String?,
      mqttBrokerPort: port is int ? port : (port is num ? port.toInt() : null),
      mqttBrokerUser: m['mqttBrokerUser'] as String?,
      mqttBrokerPassword: m['mqttBrokerPassword'] as String?,
    );
  }

  bool get hasApiUrl =>
      apiUrl != null &&
      apiUrl!.trim().isNotEmpty &&
      !ApiConfig.isLoopbackApiBase(apiUrl!);

  String? get resolvedApiBaseUrl {
    final id = deviceId.trim();
    if (id.isEmpty) return null;

    final raw = apiUrl?.trim();
    if (raw != null && raw.isNotEmpty && !ApiConfig.isLoopbackApiBase(raw)) {
      return VpsDefaults.coerceUploadBaseUri(raw);
    }

    final h = mqttBrokerHost?.trim();
    if (h != null && h.isNotEmpty) {
      if (VpsDefaults.shouldUseIpInsteadOfHostname(h)) {
        return VpsDefaults.apiBase;
      }
      return 'http://$h:${VpsDefaults.apiPort}';
    }

    return VpsDefaults.apiBase;
  }

  bool get canUploadToServer =>
      resolvedApiBaseUrl != null && resolvedFrameTargetCandidates.isNotEmpty;

  String? get resolvedPairingToken {
    final t = pairingToken?.trim();
    if (t != null && t.isNotEmpty) return t;
    return VpsDefaults.pairingToken;
  }

  bool get isWifiProvisioned => wifiSsid != null && wifiSsid!.trim().isNotEmpty;

  /// List row / editor labels when [frameName] is unset (avoids raw BLE MAC like `D0:CF:…`).
  String listDisplayTitle(AppStrings s) {
    final n = frameName?.trim();
    if (n != null && n.isNotEmpty) return n;
    return s.frameDefaultDisplayName;
  }
}
