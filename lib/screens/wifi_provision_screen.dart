import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../config/vps_defaults.dart';
import '../l10n/app_strings.dart';
import '../services/blufi_provisioning_service.dart';
import '../services/device_store.dart';
import '../services/wifi_credential_cache.dart';
import 'frame_profile_setup_screen.dart';

class WifiProvisionScreen extends StatefulWidget {
  const WifiProvisionScreen({super.key});

  @override
  State<WifiProvisionScreen> createState() => _WifiProvisionScreenState();
}

class _WifiProvisionScreenState extends State<WifiProvisionScreen> {
  static const MethodChannel _nativeBleMethod = MethodChannel('myframe/native_ble/methods');
  final _ssidCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _mqttHostCtrl = TextEditingController();
  final _mqttPortCtrl = TextEditingController(text: '1883');
  final _mqttUserCtrl = TextEditingController();
  final _mqttPassCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  final _manualKey = GlobalKey();

  List<({String ssid, int rssi, bool secure})> _wifiNetworks = [];
  String? _selectedSsid;
  bool _scanningWifi = false;
  bool _busy = false;
  bool _hide = true;
  bool _selectedIsOpen = false;
  String? _status;
  /// When false on Android with scan results, SSID/password fields stay collapsed until + is used.
  bool _showManualEntry = false;
  bool _didAutoLaunch = false;
  final Map<String, bool> _savedPasswordForSsid = {};

  @override
  void initState() {
    super.initState();
    final paired = DeviceStore.instance.cached;
    if (paired != null) {
      _ssidCtrl.text = normalizeWifiSsid(paired.wifiSsid);
      _passCtrl.text = paired.wifiPassword ?? '';
      _mqttHostCtrl.text =
          paired.mqttBrokerHost?.trim().isNotEmpty == true ? paired.mqttBrokerHost! : VpsDefaults.host;
      _mqttPortCtrl.text =
          (paired.mqttBrokerPort ?? VpsDefaults.mqttPort).toString();
      _mqttUserCtrl.text =
          paired.mqttBrokerUser?.trim().isNotEmpty == true ? paired.mqttBrokerUser! : VpsDefaults.mqttUser;
      _mqttPassCtrl.text = paired.mqttBrokerPassword ?? VpsDefaults.mqttPass;
    } else {
      _mqttHostCtrl.text = VpsDefaults.host;
      _mqttPortCtrl.text = '${VpsDefaults.mqttPort}';
      _mqttUserCtrl.text = VpsDefaults.mqttUser;
      _mqttPassCtrl.text = VpsDefaults.mqttPass;
    }
    if (Platform.isIOS) {
      _showManualEntry = true;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _seedPairedIntoCache();
      if (!mounted) return;
      if (Platform.isAndroid) {
        await _scanWifiNetworksThenAuto();
      }
    });
  }

  Future<void> _seedPairedIntoCache() async {
    final p = DeviceStore.instance.cached;
    final ssid = normalizeWifiSsid(p?.wifiSsid);
    final pwd = p?.wifiPassword;
    if (ssid.isNotEmpty && pwd != null && pwd.isNotEmpty) {
      await WifiCredentialCache.instance.remember(ssid, pwd);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _ssidCtrl.dispose();
    _passCtrl.dispose();
    _mqttHostCtrl.dispose();
    _mqttPortCtrl.dispose();
    _mqttUserCtrl.dispose();
    _mqttPassCtrl.dispose();
    super.dispose();
  }

  Future<String?> _passwordForSsid(String ssid) async {
    final key = normalizeWifiSsid(ssid);
    if (key.isEmpty) return null;
    final paired = DeviceStore.instance.cached;
    if (wifiSsidEquals(paired?.wifiSsid, key) && (paired?.wifiPassword?.isNotEmpty ?? false)) {
      return paired!.wifiPassword;
    }
    return WifiCredentialCache.instance.passwordFor(key);
  }

  Future<void> _scanWifiNetworksThenAuto() async {
    await _scanWifiNetworks();
    if (!mounted || _busy || _didAutoLaunch) return;
    final ssid = _ssidCtrl.text;
    if (normalizeWifiSsid(ssid).isEmpty) return;
    final pass = await _passwordForSsid(ssid);
    if (pass == null || pass.isEmpty) return;
    _didAutoLaunch = true;
    _passCtrl.text = pass;
    if (!mounted) return;
    setState(() => _status = AppStrings.of(context).wifiSavedPasswordConnecting);
    await Future<void>.delayed(const Duration(milliseconds: 280));
    if (mounted) await _connect();
  }

  Future<void> _scanWifiNetworks() async {
    if (!Platform.isAndroid) {
      setState(() {
        _status = 'iOS does not expose nearby Wi‑Fi scan results to apps. Enter SSID and password manually.';
      });
      return;
    }
    setState(() {
      _scanningWifi = true;
      _status = null;
    });
    try {
      await Permission.locationWhenInUse.request();
      final info = await _nativeBleMethod.invokeMethod<Map<dynamic, dynamic>>('getWifiInfo');
      final wifiEnabled = info?['enabled'] == true;
      final currentSsid = normalizeWifiSsid(info?['ssid']?.toString() ?? '');
      if (!wifiEnabled) {
        if (!mounted) return;
        setState(() {
          _wifiNetworks = const [];
          _selectedSsid = null;
          _status = 'Turn on phone Wi-Fi to scan networks.';
        });
        return;
      }
      if (kDebugMode) debugPrint('[WiFi] scan start');
      final raw = await _nativeBleMethod.invokeMethod<List<dynamic>>('scanWifiNetworks') ?? <dynamic>[];
      final parsed = <({String ssid, int rssi, bool secure})>[];
      for (final item in raw) {
        if (item is! Map) continue;
        final ssidRaw = item['ssid']?.toString() ?? '';
        final ssid = normalizeWifiSsid(ssidRaw);
        if (ssid.isEmpty) continue;
        parsed.add((
          ssid: ssid,
          rssi: (item['rssi'] as num?)?.toInt() ?? -127,
          secure: item['secure'] == true,
        ));
      }
      final savedMap = <String, bool>{};
      for (final n in parsed) {
        final pw = await _passwordForSsid(n.ssid);
        savedMap[n.ssid] = pw != null && pw.isNotEmpty;
      }
      if (!mounted) return;
      setState(() {
        _wifiNetworks = parsed;
        _savedPasswordForSsid
          ..clear()
          ..addAll(savedMap);
        if (_selectedSsid != null && !_wifiNetworks.any((n) => wifiSsidEquals(n.ssid, _selectedSsid))) {
          _selectedSsid = null;
        }
        if (currentSsid.isNotEmpty &&
            currentSsid != '<unknown ssid>' &&
            _wifiNetworks.any((n) => wifiSsidEquals(n.ssid, currentSsid))) {
          _selectedSsid = currentSsid;
          _ssidCtrl.text = currentSsid;
        }
        if (_wifiNetworks.isEmpty) {
          _status = 'No Wi-Fi networks found. You can still enter SSID manually.';
          _showManualEntry = true;
        }
      });
      if (kDebugMode) debugPrint('[WiFi] scan done count=${parsed.length}');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _status = 'Unable to scan Wi-Fi networks. You can still enter SSID manually.';
        _showManualEntry = true;
      });
    } finally {
      if (mounted) setState(() => _scanningWifi = false);
    }
  }

  void _openManualEntry() {
    setState(() => _showManualEntry = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _manualKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _onPickNetwork(String ssid) async {
    if (_busy) return;
    ({String ssid, int rssi, bool secure})? network;
    for (final n in _wifiNetworks) {
      if (wifiSsidEquals(n.ssid, ssid)) {
        network = n;
        break;
      }
    }
    final pass = await _passwordForSsid(ssid);
    if (!mounted) return;
    setState(() {
      _selectedSsid = normalizeWifiSsid(ssid);
      _ssidCtrl.text = _selectedSsid!;
      _selectedIsOpen = network?.secure == false;
      if (pass != null && pass.isNotEmpty) {
        _passCtrl.text = pass;
        _status = AppStrings.of(context).wifiSavedPasswordConnecting;
      } else if (_selectedIsOpen) {
        _passCtrl.clear();
        _status = 'Open network selected. Password not required.';
      } else {
        _passCtrl.clear();
        _status = AppStrings.of(context).wifiEnterPasswordForNetwork;
        _showManualEntry = true;
      }
    });
    if (network != null && network.secure && (pass == null || pass.isEmpty)) {
      _openManualEntry();
      return;
    }
    if (!_busy) {
      await _connect();
    }
  }

  Future<void> _connect() async {
    final paired = DeviceStore.instance.cached;
    final currentSsid = normalizeWifiSsid(_ssidCtrl.text);
    final knownSsid = paired?.wifiSsid;
    final knownPass = paired?.wifiPassword ?? '';
    final usingKnownNetwork = wifiSsidEquals(knownSsid, currentSsid) && (knownPass.isNotEmpty);
    final cached = await WifiCredentialCache.instance.passwordFor(currentSsid) ?? '';
    final effectivePassword = _passCtrl.text.isNotEmpty
        ? _passCtrl.text
        : (usingKnownNetwork ? knownPass : cached);
    if (!_formKey.currentState!.validate()) return;
    for (final n in _wifiNetworks) {
      if (wifiSsidEquals(n.ssid, currentSsid) && n.secure && effectivePassword.isEmpty) {
        setState(() {
          _status = 'This network is secured — enter its Wi‑Fi password.';
          _showManualEntry = true;
        });
        _openManualEntry();
        return;
      }
    }
    setState(() {
      _busy = true;
      _status = null;
    });
    if (paired == null) {
      if (kDebugMode) debugPrint('[WiFi] connect aborted: no paired frame in DeviceStore');
      setState(() {
        _busy = false;
        _status = 'No paired frame selected';
      });
      return;
    }
    if (kDebugMode) {
      debugPrint(
        '[WiFi] connect start ssid="${_ssidCtrl.text.trim()}" pwdLen=${effectivePassword.length} '
        'paired deviceId=${paired.deviceId} bleRemoteId=${paired.bleRemoteId} bleNamePrefix=${paired.bleNamePrefix}',
      );
    }
    final mqHost = _mqttHostCtrl.text.trim();
    final mqPort = int.tryParse(_mqttPortCtrl.text.trim()) ?? 1883;
    await DeviceStore.instance.saveSelfHostedMqtt(
      host: mqHost,
      port: mqPort,
      user: _mqttUserCtrl.text.trim(),
      password: _mqttPassCtrl.text,
    );
    final selfHostedMqtt = mqHost.isEmpty
        ? null
        : SelfHostedMqttConfig(
            host: mqHost,
            port: mqPort,
            user: _mqttUserCtrl.text.trim(),
            password: _mqttPassCtrl.text,
          );
    final provision = await BlufiProvisioningService.instance.provision(
      paired: paired,
      ssid: _ssidCtrl.text.trim(),
      password: effectivePassword,
      selfHostedMqtt: selfHostedMqtt,
    );
    if (kDebugMode) {
      debugPrint(
        '[WiFi] provision result ok=${provision.ok} confirmed=${provision.confirmed} message="${provision.message}"',
      );
    }
    if (!mounted) return;
    if (!provision.ok || !provision.confirmed) {
      setState(() {
        _busy = false;
        _status = provision.message;
      });
      return;
    }
    if (kDebugMode) debugPrint('[WiFi] frame confirmed Wi‑Fi — saving SSID, opening profile setup…');
    await DeviceStore.instance.saveWifiProvision(
      ssid: _ssidCtrl.text,
      password: effectivePassword,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _status = AppStrings.of(context).wifiConnectSuccess(_ssidCtrl.text.trim());
    });
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    final nav = Navigator.of(context);
    final profileOk = await nav.push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const FrameProfileSetupScreen()),
    );
    if (!mounted) return;
    nav.pop(profileOk == true);
  }

  Widget _rssiBars(int rssi, ColorScheme cs) {
    final t = ((rssi + 100) / 60).clamp(0.0, 1.0);
    final filled = (t * 4).round().clamp(0, 4);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(4, (i) {
        final on = i < filled;
        return Container(
          width: 5,
          height: 12,
          margin: const EdgeInsets.only(right: 2),
          decoration: BoxDecoration(
            color: on ? cs.primary : cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final cs = Theme.of(context).colorScheme;
    final showFormFields = _showManualEntry || Platform.isIOS || _wifiNetworks.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.wifiSetupTitle),
        actions: [
          if (Platform.isAndroid)
            IconButton(
              tooltip: s.wifiRescanNetworks,
              onPressed: (_busy || _scanningWifi) ? null : () => unawaited(_scanWifiNetworks()),
              icon: _scanningWifi
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: cs.onSurface),
                    )
                  : const Icon(Icons.wifi_find),
            ),
          IconButton(
            tooltip: s.wifiAddNetworkManually,
            onPressed: _busy ? null : _openManualEntry,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        children: [
          Text(s.wifiSetupBody, style: TextStyle(color: cs.onSurfaceVariant, height: 1.4)),
          if (Platform.isIOS) ...[
            const SizedBox(height: 8),
            Text(
              'On iPhone, type the Wi‑Fi name (SSID) and password manually.',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
            ),
          ],
          if (Platform.isAndroid && _wifiNetworks.isNotEmpty && !_showManualEntry) ...[
            const SizedBox(height: 8),
            Text(
              s.wifiTapPlusForNewNetwork,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
            ),
          ],
          const SizedBox(height: 14),
          if (Platform.isAndroid && _scanningWifi && _wifiNetworks.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Text(s.wifiScanningNetworks, style: TextStyle(fontWeight: FontWeight.w600, color: cs.primary)),
                ],
              ),
            ),
          if (Platform.isAndroid && _wifiNetworks.isNotEmpty) ...[
            Text(s.wifiNearbyNetworksTitle, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final n in _wifiNetworks)
                    ListTile(
                      selected: wifiSsidEquals(_selectedSsid, n.ssid),
                      leading: Icon(n.secure ? Icons.wifi_lock_outlined : Icons.wifi_outlined),
                      title: Text(n.ssid, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Row(
                        children: [
                          _rssiBars(n.rssi, cs),
                          const SizedBox(width: 8),
                          Text(
                            '${n.rssi} dBm · ${n.secure ? 'Secured' : 'Open'}',
                            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                          ),
                          if (_savedPasswordForSsid[n.ssid] == true) ...[
                            const SizedBox(width: 8),
                            Icon(Icons.key, size: 16, color: cs.tertiary),
                          ],
                        ],
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _busy ? null : () => unawaited(_onPickNetwork(n.ssid)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          Card(
            key: _manualKey,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!showFormFields)
                      Text(
                        s.wifiManualEntryCollapsedHint,
                        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                      ),
                    Visibility(
                      visible: showFormFields,
                      maintainState: true,
                      maintainAnimation: true,
                      maintainSize: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _ssidCtrl,
                            decoration: InputDecoration(
                              labelText: s.wifiSsidLabel,
                              prefixIcon: const Icon(Icons.wifi),
                            ),
                            validator: (v) {
                              if (v == null || normalizeWifiSsid(v).isEmpty) return s.wifiSsidRequired;
                              return null;
                            },
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _passCtrl,
                            obscureText: _hide,
                            decoration: InputDecoration(
                              labelText: s.wifiPasswordLabel,
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                onPressed: () => setState(() => _hide = !_hide),
                                icon: Icon(_hide ? Icons.visibility : Icons.visibility_off),
                              ),
                            ),
                            validator: (v) {
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    ExpansionTile(
                      title: const Text('Self-hosted MQTT (optional)'),
                      subtitle: Text(
                        'Send your VPS broker to the frame after Wi‑Fi (empty = use factory cloud).',
                        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                      ),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      children: [
                        TextFormField(
                          controller: _mqttHostCtrl,
                          decoration: const InputDecoration(
                            labelText: 'MQTT host',
                            hintText: 'mqtt.example.com',
                            prefixIcon: Icon(Icons.dns_outlined),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _mqttPortCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'MQTT port',
                            prefixIcon: Icon(Icons.numbers),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _mqttUserCtrl,
                          decoration: const InputDecoration(
                            labelText: 'MQTT user (optional)',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _mqttPassCtrl,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'MQTT password (optional)',
                            prefixIcon: Icon(Icons.key_outlined),
                          ),
                        ),
                      ],
                    ),
                    if (_status != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _status!,
                        style: TextStyle(color: cs.primary, fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _busy ? null : _connect,
                        icon: _busy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.wifi_tethering),
                        label: Text(_busy ? s.connectingWifi : s.connectWifiButton),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _busy ? null : () => Navigator.of(context).pop(false),
                      child: Text(s.skipForNow),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
