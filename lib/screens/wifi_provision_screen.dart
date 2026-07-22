import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../config/vps_defaults.dart';
import '../l10n/app_strings.dart';
import '../models/pairing_nav_result.dart';
import '../services/blufi_provisioning_service.dart';
import '../services/device_store.dart';
import '../services/wifi_credential_cache.dart';
import 'frame_profile_setup_screen.dart';
import '../services/permission_gate.dart';
import '../navigation/pairing_flow_nav.dart';
import '../services/app_diag_log.dart';
import '../widgets/debug_slog_overlay.dart';

const _kRed = Color(0xFFE5252A);

class WifiProvisionScreen extends StatefulWidget {
  const WifiProvisionScreen({
    super.key,
    this.firstTimeSetup = false,
    this.serverConfigAlreadySent = false,
    this.openSendAfterSetup = true,
  });

  final bool firstTimeSetup;
  final bool serverConfigAlreadySent;
  final bool openSendAfterSetup;

  @override
  State<WifiProvisionScreen> createState() => _WifiProvisionScreenState();
}

class _WifiProvisionScreenState extends State<WifiProvisionScreen> {
  static const MethodChannel _nativeBleMethod = MethodChannel('myframe/native_ble/methods');
  final _ssidCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _scrollController = ScrollController();

  List<({String ssid, int rssi, bool secure})> _wifiNetworks = [];
  String? _selectedSsid;
  bool _scanningWifi = false;
  bool _busy = false;
  bool _hide = true;
  bool _showManualEntry = false;
  bool _selectedIsOpen = false;
  String? _status;
  String? _error;
  bool _didAutoLaunch = false;
  bool _wifiConfirmed = false;
  String? _currentWifiSsid;
  String? _frameMac;

  @override
  void initState() {
    super.initState();
    final paired = DeviceStore.instance.cached;
    if (paired != null) {
      _ssidCtrl.text = normalizeWifiSsid(paired.wifiSsid);
      _passCtrl.text = paired.wifiPassword ?? '';
      _frameMac = paired.deviceId;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _seedPairedIntoCache();
      if (!mounted) return;
      await _scanWifiNetworksThenAuto();
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
    final s = AppStrings.of(context);
    setState(() => _status = s.wifiConnectingSavedPassword);
    if (mounted) await _connect();
  }

  Future<void> _scanWifiNetworks() async {
    setState(() {
      _scanningWifi = true;
      _status = null;
      _error = null;
    });
    try {
      try {
        if (Platform.isAndroid) {
          await PermissionGate.locationWhenInUse();
          final loc = await Permission.locationWhenInUse.status;
          if (!loc.isGranted && !loc.isLimited) {
            await PermissionGate.enqueueLocationCoarse();
          }
        }
      } catch (_) {}
      final info = await _nativeBleMethod.invokeMethod<Map<dynamic, dynamic>>('getWifiInfo');
      final currentSsid = normalizeWifiSsid(info?['ssid']?.toString() ?? '');
      if (currentSsid.isNotEmpty && currentSsid != '<unknown ssid>') {
        setState(() {
          _currentWifiSsid = currentSsid;
          _ssidCtrl.text = currentSsid;
          _selectedSsid = currentSsid;
        });
      }
      if (!Platform.isAndroid) {
        setState(() {
          _showManualEntry = true;
          _scanningWifi = false;
        });
        return;
      }
      final wifiEnabled = info?['enabled'] == true;
      if (!wifiEnabled) {
        if (!mounted) return;
        setState(() {
          _wifiNetworks = const [];
          _selectedSsid = null;
          _scanningWifi = false;
          _showManualEntry = true;
        });
        return;
      }
      AppDiagLog.verbose('[WiFi] scan start');
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
      if (!mounted) return;
      setState(() {
        _wifiNetworks = parsed;
        if (_wifiNetworks.isEmpty) {
          _showManualEntry = true;
        }
      });
      AppDiagLog.verbose('[WiFi] scan done count=${parsed.length}');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _showManualEntry = true;
      });
    } finally {
      if (mounted) setState(() => _scanningWifi = false);
    }
  }

  void _onSelectNetwork(String ssid, bool secure) {
    if (_busy) return;
    setState(() {
      _selectedSsid = normalizeWifiSsid(ssid);
      _ssidCtrl.text = _selectedSsid!;
      _selectedIsOpen = !secure;
      _error = null;
      _status = null;
    });
    if (!secure) {
      _passCtrl.clear();
    }
  }

  Widget _signalBar(int rssi) {
    final t = ((rssi + 100) / 60).clamp(0.0, 1.0);
    final filled = (t * 4).round().clamp(0, 4);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(4, (i) {
        final on = i < filled;
        return Container(
          width: 6,
          height: 12,
          margin: const EdgeInsets.only(right: 2),
          decoration: BoxDecoration(
            color: on ? _kRed : const Color(0xFFEEEEEE),
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }

  Future<void> _connect() async {
    try {
      await _connectInner();
    } catch (e, st) {
      AppDiagLog.verbose('[WiFi] connect failed: $e\n$st');
      if (!mounted) return;
      final s = AppStrings.of(context);
      setState(() {
        _busy = false;
        _error = AppDiagLog.userFacingStatus(
          e.toString(),
          fallback: s.wifiConnectionFailed,
        );
      });
    }
  }

  Future<void> _connectInner() async {
    final s = AppStrings.of(context);
    final paired = DeviceStore.instance.cached;
    final currentSsid = normalizeWifiSsid(_ssidCtrl.text);
    final knownPass = paired?.wifiPassword ?? '';
    final cached = await WifiCredentialCache.instance.passwordFor(currentSsid) ?? '';
    final effectivePassword = _passCtrl.text.isNotEmpty
        ? _passCtrl.text
        : (knownPass.isNotEmpty ? knownPass : cached);

    final secure = _wifiNetworks.any((n) => wifiSsidEquals(n.ssid, currentSsid) && n.secure);
    if (currentSsid.isEmpty) {
      setState(() {
        _error = s.wifiSsidRequired;
      });
      return;
    }
    if (secure && effectivePassword.isEmpty) {
      setState(() {
        _error = s.wifiRequiresPasswordError;
      });
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _status = s.connectingWifi;
    });

    if (paired == null) {
      setState(() {
        _busy = false;
        _error = s.firmwareNoDevice;
      });
      return;
    }

    AppDiagLog.verbose(
      '[WiFi] connect start ssid="$currentSsid" pwdLen=${effectivePassword.length}',
    );

    final selfHostedMqtt = SelfHostedMqttConfig(
      host: VpsDefaults.host,
      port: VpsDefaults.mqttPort,
      user: VpsDefaults.mqttUser,
      password: VpsDefaults.mqttPass,
    );

    final provision = await BlufiProvisioningService.instance.provision(
      paired: paired,
      ssid: currentSsid,
      password: effectivePassword,
      selfHostedMqtt: selfHostedMqtt,
      serverConfigAlreadySent: widget.serverConfigAlreadySent,
    );

    AppDiagLog.verbose(
      '[WiFi] provision result ok=${provision.ok} confirmed=${provision.confirmed} message="${provision.message}"',
    );

    if (!mounted) return;

    if (!provision.ok || !provision.confirmed) {
      setState(() {
        _busy = false;
        _error = AppDiagLog.userFacingStatus(
          provision.message,
          fallback: s.wifiConnectFrameFailed,
        );
      });
      return;
    }

    AppDiagLog.verbose('[WiFi] frame confirmed Wi‑Fi — saving SSID, opening profile setup…');
    await DeviceStore.instance.saveWifiProvision(
      ssid: currentSsid,
      password: effectivePassword,
    );

    if (!mounted) return;
    setState(() {
      _busy = false;
      _wifiConfirmed = true;
      _status = '${s.wifiConnectedTo} $currentSsid';
    });

    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    final profileOk = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => FrameProfileSetupScreen(
          requiredSetup: widget.firstTimeSetup,
        ),
      ),
    );

    if (!mounted) return;
    if (widget.firstTimeSetup) {
      final openSend = profileOk == true && widget.openSendAfterSetup;
      final result = PairingNavResult(
        success: profileOk == true,
        openSendGallery: openSend,
      );
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop<PairingNavResult>(result);
      }
      if (openSend) {
        PairingFlowNav.onComplete(result);
      }
      return;
    }
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop<bool>(profileOk == true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final cs = Theme.of(context).colorScheme;
    final paired = DeviceStore.instance.cached;
    final mac = _frameMac ?? paired?.deviceId ?? '';

    return DebugSlogOverlay(
      child: Scaffold(
        backgroundColor: cs.surface,
        appBar: AppBar(
          title: Text(s.wifiSetupTitle, style: const TextStyle(fontWeight: FontWeight.w700)),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0.5,
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  // Frame info strip
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cs.outlineVariant),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.appName,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'MAC · ${mac.isNotEmpty ? mac : s.unknownLabel}',
                          style: TextStyle(
                            fontSize: 13,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Available WiFi networks card (scrollable rectangle at top)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 4),
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cs.outlineVariant),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.wifiSsidLabel,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          s.wifiProvisionPhoneHint,
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                          ),
                        ),

                        // Current WiFi
                        if (_currentWifiSsid != null && _currentWifiSsid!.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: cs.outlineVariant),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        s.wifiCurrentNetwork,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: cs.onSurfaceVariant,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _currentWifiSsid!,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: cs.onSurface,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => _onSelectNetwork(_currentWifiSsid!, true),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: _kRed,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      s.wifiUseNetwork,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Scanning indicator
                        if (_scanningWifi && _wifiNetworks.isEmpty && (_currentWifiSsid == null || _currentWifiSsid!.isEmpty)) ...[
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: _kRed,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                s.wifiScanningNetworks,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _kRed,
                                ),
                              ),
                            ],
                          ),
                        ],

                        // Other networks scrollable list
                        if (_wifiNetworks.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            s.wifiNearbyNetworksTitle,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            constraints: const BoxConstraints(maxHeight: 200),
                            decoration: BoxDecoration(
                              border: Border.all(color: cs.outlineVariant),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              padding: EdgeInsets.zero,
                              itemCount: _wifiNetworks.length,
                              separatorBuilder: (_, __) => Divider(
                                height: 1,
                                color: cs.outlineVariant,
                              ),
                              itemBuilder: (context, i) {
                                final n = _wifiNetworks[i];
                                final selected = wifiSsidEquals(_selectedSsid, n.ssid);
                                return InkWell(
                                  onTap: () => _onSelectNetwork(n.ssid, n.secure),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    color: selected
                                        ? _kRed.withValues(alpha: 0.08)
                                        : Colors.transparent,
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                n.ssid,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w700,
                                                  color: cs.onSurface,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                n.secure ? s.wifiPasswordRequiredLabel : s.wifiOpenNetworkLabel,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: cs.onSurfaceVariant,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        _signalBar(n.rssi),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],

                        const SizedBox(height: 10),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // WiFi manual entry card (SSID + password)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cs.outlineVariant),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.wifiSsidLabel,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _ssidCtrl,
                          style: const TextStyle(fontSize: 15),
                          decoration: InputDecoration(
                            hintText: s.wifiSsidRequired,
                            filled: true,
                            fillColor: cs.surfaceContainerLow,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: cs.outlineVariant),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: cs.outlineVariant),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            isDense: true,
                          ),
                        ),

                        // Password section
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: _kRed.withValues(alpha: 0.28),
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    s.wifiPasswordLabel,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: cs.onSurface,
                                    ),
                                  ),
                                  const Spacer(),
                                  GestureDetector(
                                    onTap: () => setState(() => _hide = !_hide),
                                    child: Text(
                                      _hide ? s.wifiShowPassword : s.wifiHidePassword,
                                      style: const TextStyle(
                                        color: _kRed,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                s.wifiRequiredForNetwork,
                                style: TextStyle(
                                  color: _kRed,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _passCtrl,
                                obscureText: _hide,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                decoration: InputDecoration(
                                  hintText: s.wifiPasswordRequired,
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: cs.outlineVariant, width: 1.5),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: cs.outlineVariant, width: 1.5),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  isDense: true,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                s.wifiLeaveBlankHint,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Status
                  if (_status != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: cs.outlineVariant),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                            Text(
                              _busy ? s.connectingWifi : s.statusLabel,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _status!,
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Error
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _kRed.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _kRed.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, size: 16, color: _kRed),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: TextStyle(
                                fontSize: 12,
                                color: _kRed,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),
                ],
              ),
            ),

            // Bottom action bar
            Container(
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                16 + MediaQuery.of(context).padding.bottom,
              ),
              decoration: BoxDecoration(
                color: cs.surface,
                border: Border(top: BorderSide(color: cs.outlineVariant)),
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: (_busy || _wifiConfirmed)
                        ? null
                        : _connect,
                    style: FilledButton.styleFrom(
                      backgroundColor: _kRed,
                      disabledBackgroundColor: _kRed.withValues(alpha: 0.45),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(100),
                      ),
                      elevation: 4,
                      shadowColor: _kRed.withValues(alpha: 0.25),
                    ),
                    child: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                            : Text(
                                _wifiConfirmed ? s.wifiConnectedLabel : s.wifiConnectNowLabel,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
