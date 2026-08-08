import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../config/vps_defaults.dart';
import '../l10n/app_strings.dart';
import '../models/pairing_nav_result.dart';
import '../services/account_sync_service.dart';
import '../services/auth_session_manager.dart';
import '../services/blufi_provisioning_service.dart';
import '../services/device_store.dart';
import '../services/frame_mac_util.dart';
import '../services/wifi_credential_cache.dart';
import 'frame_profile_setup_screen.dart';
import '../services/permission_gate.dart';
import '../navigation/pairing_flow_nav.dart';
import '../services/app_diag_log.dart';
import '../widgets/debug_slog_overlay.dart';
import '../widgets/progress_action_button.dart';

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

  /// Bumped on every scan start; stale async results whose generation is
  /// behind the latest scan are dropped so overlapping scans never clobber
  /// the freshly returned list.
  int _wifiScanEpoch = 0;
  bool _busy = false;
  bool _hide = true;
  bool _selectedIsOpen = false;
  String? _status;
  String? _error;
  bool _wifiConfirmed = false;
  String? _currentWifiSsid;
  String? _frameMac;

  @override
  void initState() {
    super.initState();
    final paired = DeviceStore.instance.cached;
    if (paired != null) {
      // Prefill SSID only — never password; never auto-connect.
      _ssidCtrl.text = normalizeWifiSsid(paired.wifiSsid);
      _frameMac = paired.deviceId;
    }
    _passCtrl.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_scanWifiNetworks());
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _ssidCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _scanWifiNetworks() async {
    final epoch = ++_wifiScanEpoch;
    setState(() {
      _scanningWifi = true;
      _status = null;
      _error = null;
    });
    try {
      try {
        await PermissionGate.locationWhenInUse();
        if (Platform.isAndroid) {
          await PermissionGate.nearbyWifiDevices();
          final loc = await Permission.locationWhenInUse.status;
          final nearby = await Permission.nearbyWifiDevices.status;
          if (!loc.isGranted && !loc.isLimited && !nearby.isGranted) {
            await PermissionGate.enqueueLocationCoarse();
          }
          final loc2 = await Permission.locationWhenInUse.status;
          final nearby2 = await Permission.nearbyWifiDevices.status;
          if (!loc2.isGranted && !loc2.isLimited && !nearby2.isGranted) {
            if (!mounted || epoch != _wifiScanEpoch) return;
            setState(() {
              _error = AppStrings.of(context).wifiScanPermissionHint;
            });
          }
        }
      } catch (_) {}

      final info = await _nativeBleMethod
          .invokeMethod<Map<dynamic, dynamic>>('getWifiInfo')
          .timeout(const Duration(seconds: 10));
      final currentSsid = normalizeWifiSsid(info?['ssid']?.toString() ?? '');
      if (currentSsid.isNotEmpty && currentSsid != '<unknown ssid>') {
        if (!mounted || epoch != _wifiScanEpoch) return;
        setState(() {
          _currentWifiSsid = currentSsid;
          if (_ssidCtrl.text.trim().isEmpty) {
            _ssidCtrl.text = currentSsid;
            _selectedSsid = currentSsid;
          }
        });
      }

      // iOS: no public nearby-SSID API — current network + manual entry only.
      if (!Platform.isAndroid) {
        if (!mounted || epoch != _wifiScanEpoch) return;
        setState(() {
          _wifiNetworks = const [];
          _scanningWifi = false;
        });
        return;
      }

      final wifiEnabled = info?['enabled'] == true;
      if (!wifiEnabled) {
        if (!mounted || epoch != _wifiScanEpoch) return;
        setState(() {
          _wifiNetworks = const [];
          _selectedSsid = null;
          _scanningWifi = false;
        });
        return;
      }

      AppDiagLog.verbose('[WiFi] scan start');
      var raw = await _nativeBleMethod
          .invokeMethod<List<dynamic>>('scanWifiNetworks')
          // Android startScan() can stall (throttle / lost SCAN_RESULTS broadcast);
          // never leave the spinner stuck or the next scan queued forever.
          .timeout(const Duration(seconds: 12)) ?? <dynamic>[];
      // One retry if the first pass returned empty (scan throttle / cold start).
      if (raw.isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 700));
        raw = await _nativeBleMethod
            .invokeMethod<List<dynamic>>('scanWifiNetworks')
            .timeout(const Duration(seconds: 12)) ?? <dynamic>[];
      }
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
      // A newer scan started while this one was in flight — drop these results.
      if (!mounted || epoch != _wifiScanEpoch) return;
      setState(() {
        _wifiNetworks = parsed;
      });
      AppDiagLog.verbose('[WiFi] scan done count=${parsed.length}');
    } catch (_) {
      if (!mounted || epoch != _wifiScanEpoch) return;
    } finally {
      if (mounted && epoch == _wifiScanEpoch) {
        setState(() => _scanningWifi = false);
      }
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
    // Never auto-fill password — user types it (or leaves blank for open Wi‑Fi).
    _passCtrl.clear();
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
    FocusScope.of(context).unfocus();
    try {
      await _connectInner();
    } catch (e, st) {
      AppDiagLog.verbose('[WiFi] connect failed: $e\n$st');
      await DeviceStore.instance.clearWifiProvision();
      if (!mounted) return;
      final s = AppStrings.of(context);
      setState(() {
        _busy = false;
        _wifiConfirmed = false;
        _status = null;
        _error = AppDiagLog.userFacingStatus(
          e.toString(),
          fallback: s.wifiConnectionFailed,
        );
      });
    } finally {
      // Ensure 401 handling is re-enabled even if pairing fails.
      AuthSessionManager.instance.suppressUnauthorizedHandling(false);
    }
  }

  Future<void> _connectInner() async {
    // Suppress 401 handling during the entire pairing flow (WiFi provisioning +
    // profile setup) so transient 401s from pairing endpoints don't log the user
    // out. The AuthSessionManager will not reset the session while this is true.
    AuthSessionManager.instance.suppressUnauthorizedHandling(true);
    try {
      final s = AppStrings.of(context);
      final paired = DeviceStore.instance.cached;
      final currentSsid = normalizeWifiSsid(_ssidCtrl.text);
      // Password is only what the user typed — never cached/saved auto-fill.
      // Trim only trailing/leading spaces; empty string = open network.
      final effectivePassword = _passCtrl.text;
      final match = _wifiNetworks.where(
        (n) => wifiSsidEquals(n.ssid, currentSsid),
      );
      final listedSecure = match.isNotEmpty && match.first.secure;
      // Prefer explicit open selection / blank password over a flaky scan "secure" bit.
      final treatAsOpen =
          _selectedIsOpen || (!listedSecure && effectivePassword.isEmpty);
      if (currentSsid.isEmpty) {
        setState(() {
          _error = s.wifiSsidRequired;
        });
        return;
      }
      if (listedSecure && !treatAsOpen && effectivePassword.isEmpty) {
        setState(() {
          _error = s.wifiRequiresPasswordError;
        });
        return;
      }

      setState(() {
        _busy = true;
        _error = null;
        _status = s.connectingWifi;
        _wifiConfirmed = false;
      });

      if (paired == null) {
        // This is Wi‑Fi setup, not firmware management — never surface the
        // "pair a frame to manage firmware updates" banner here.
        setState(() {
          _busy = false;
          _error = s.noFramePaired;
        });
        return;
      }

      AppDiagLog.verbose(
        '[WiFi] connect start ssid="$currentSsid" pwdLen=${effectivePassword.length} open=$treatAsOpen',
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
        // Never persist a failed SSID as "connected".
        await DeviceStore.instance.clearWifiProvision();
        if (!mounted) return;
        setState(() {
          _busy = false;
          _wifiConfirmed = false;
          _status = null;
          _error = AppDiagLog.userFacingStatus(
            provision.message,
            fallback: s.wifiConnectionFailed,
          );
        });
        return;
      }

      AppDiagLog.verbose('[WiFi] frame confirmed Wi‑Fi — saving SSID, opening profile setup…');
      await DeviceStore.instance.saveWifiProvision(
        ssid: currentSsid,
        password: effectivePassword,
      );

      // Manual pairing won ownership of this hardware — clear any unbound ban
      // from a prior unlink and claim/re-push the owner binding so the frame
      // works again without logging out.
      unawaited(
        AccountSyncService.instance.grantOwnerForManualPair(paired.deviceId),
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
    } finally {
      // Re-enable 401 handling now that pairing/profile setup is complete.
      AuthSessionManager.instance.suppressUnauthorizedHandling(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final cs = Theme.of(context).colorScheme;
    final paired = DeviceStore.instance.cached;
    final rawMac = _frameMac ?? paired?.deviceId ?? '';
    final mac = rawMac.isNotEmpty ? FrameMacUtil.normalizeSlug(rawMac) ?? rawMac : '';

    return DebugSlogOverlay(
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
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
                  const SizedBox(height: 16),

                  // Wi‑Fi selection: current phone network + optional nearby list
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
                        if (Platform.isAndroid)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: (_busy || _scanningWifi) ? null : _scanWifiNetworks,
                              icon: _scanningWifi
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: _kRed,
                                      ),
                                    )
                                  : const Icon(Icons.refresh, size: 18, color: _kRed),
                              label: Text(
                                s.wifiRescanNetworks,
                                style: const TextStyle(
                                  color: _kRed,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              style: TextButton.styleFrom(
                                foregroundColor: _kRed,
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                          ),

                        // Current phone Wi‑Fi shortcut
                        if (_currentWifiSsid != null && _currentWifiSsid!.isNotEmpty)
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
                                  onTap: () {
                                    final ssid = _currentWifiSsid!;
                                    final match = _wifiNetworks.where(
                                      (n) => wifiSsidEquals(n.ssid, ssid),
                                    );
                                    final secure = match.isEmpty ? false : match.first.secure;
                                    _onSelectNetwork(ssid, secure);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: _kRed,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      s.wifiUseNetwork,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else if (_scanningWifi)
                          Row(
                            children: [
                              const SizedBox(
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
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _kRed,
                                ),
                              ),
                            ],
                          ),

                        // Nearby networks (Android scan)
                        if (_wifiNetworks.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text(
                            s.wifiNearbyNetworksTitle,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface,
                            ),
                          ),
                          const SizedBox(height: 8),
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
                                                n.secure
                                                    ? s.wifiPasswordRequiredLabel
                                                    : s.wifiOpenNetworkLabel,
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
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // SSID + password inputs
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
                        const SizedBox(height: 8),
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

                        const SizedBox(height: 16),

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
                                style: const TextStyle(
                                  color: _kRed,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _passCtrl,
                                obscureText: _hide,
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => _connect(),
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                decoration: InputDecoration(
                                  hintText: s.wifiPasswordRequired,
                                  filled: true,
                                  fillColor: cs.surface,
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
                    const SizedBox(height: 16),
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
                    const SizedBox(height: 16),
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
                          const Icon(Icons.error_outline, size: 16, color: _kRed),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(
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
                child: ProgressActionButton(
                  height: 52,
                  borderRadius: BorderRadius.circular(100),
                  backgroundColor: _kRed,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _kRed.withValues(alpha: 0.45),
                  label: _wifiConfirmed
                      ? s.wifiConnectedLabel
                      : s.wifiConnectNowLabel,
                  isLoading: _busy,
                  statusMessage: (_status?.trim().isNotEmpty == true)
                      ? _status!.replaceAll(RegExp(r'[.…]+$'), '').trim()
                      : s.progressConfiguringFrameBusy,
                  progress: null,
                  onPressed: (_busy || _wifiConfirmed) ? null : _connect,
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
