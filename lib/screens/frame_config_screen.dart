import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_config.dart';
import '../models/pairing_nav_result.dart';
import '../services/device_store.dart';
import '../services/frame_manual_config_service.dart';
import '../navigation/pairing_flow_nav.dart';
import 'wifi_provision_screen.dart';

enum _SendPhase { idle, sending, waitingOnline, success, warning }

/// Manual MQTT config over BLE (EspBluFi-style JSON editor).
class FrameConfigScreen extends StatefulWidget {
  const FrameConfigScreen({
    super.key,
    this.initialDeviceName,
    this.initialMac,
    this.preconnectedRemoteId,
  });

  final String? initialDeviceName;
  final String? initialMac;
  final String? preconnectedRemoteId;

  @override
  State<FrameConfigScreen> createState() => _FrameConfigScreenState();
}

class _FrameConfigScreenState extends State<FrameConfigScreen> {
  final _svc = FrameManualConfigService.instance;
  final _configCtrl = TextEditingController();
  final _logScroll = ScrollController();

  List<FrameBleDevice> _devices = [];
  FrameBleDevice? _selected;
  bool _scanning = false;
  bool _connecting = false;
  bool _busy = false;
  _SendPhase _phase = _SendPhase.idle;
  String? _jsonError;
  final List<String> _log = [];

  @override
  void initState() {
    super.initState();
    _resetConfigEditor();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _configCtrl.dispose();
    _logScroll.dispose();
    unawaited(_svc.disconnect());
    super.dispose();
  }

  Future<void> _bootstrap() async {
    if (widget.preconnectedRemoteId != null &&
        widget.preconnectedRemoteId!.trim().isNotEmpty) {
      await _connectPrelinked();
      return;
    }
    await _startScan();
  }

  void _resetConfigEditor() {
    _configCtrl.text = AppConfig.defaultFrameConfig;
    _validateJson();
  }

  void _addLog(String line) {
    final now = DateTime.now();
    final ts =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    setState(() => _log.add('[$ts] $line'));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logScroll.hasClients) {
        _logScroll.jumpTo(_logScroll.position.maxScrollExtent);
      }
    });
  }

  void _validateJson() {
    try {
      final decoded = _configCtrl.text.trim();
      if (decoded.isEmpty) {
        setState(() => _jsonError = 'JSON is empty');
        return;
      }
      jsonDecode(decoded);
      setState(() => _jsonError = null);
    } catch (e) {
      setState(() => _jsonError = e.toString());
    }
  }

  Future<void> _startScan() async {
    setState(() {
      _scanning = true;
      _devices = [];
    });
    try {
      final found = await _svc.scan(onLog: _addLog);
      if (!mounted) return;
      setState(() => _devices = found);
    } catch (e) {
      _addLog('Scan error: $e');
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _connectPrelinked() async {
    final rid = widget.preconnectedRemoteId!.trim();
    final name = widget.initialDeviceName?.trim() ?? rid;
    final mac = widget.initialMac?.trim() ?? '';
    setState(() => _connecting = true);
    try {
      await _svc.connectByRemoteId(rid, onLog: _addLog);
      if (!mounted) return;
      setState(() {
        _selected = FrameBleDevice(
          device: _svc.connectedDevice!,
          name: name,
          rssi: 0,
          mac: mac,
        );
      });
      if (mac.isNotEmpty) {
        await _maybeSkipIfOnline(mac);
      }
    } catch (e) {
      _addLog('Connect error: $e');
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _connectDevice(FrameBleDevice d) async {
    setState(() {
      _connecting = true;
      _selected = d;
    });
    try {
      await _svc.connect(d.device, onLog: _addLog);
      await DeviceStore.instance.savePairedFrameMac(d.mac);
      await _maybeSkipIfOnline(d.mac);
    } catch (e) {
      _addLog('Connect error: $e');
      if (mounted) setState(() => _selected = null);
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _maybeSkipIfOnline(String mac) async {
    final online = await _svc.checkFrameOnServer(mac, onLog: _addLog);
    if (!mounted) return;
    if (online) {
      setState(() => _phase = _SendPhase.success);
    }
  }

  Future<void> _sendConfig() async {
    HapticFeedback.lightImpact();
    if (_selected == null || _jsonError != null || _busy) return;
    setState(() {
      _busy = true;
      _phase = _SendPhase.sending;
    });
    _addLog('Sending config to frame…');
    try {
      await _svc.sendConfig(_configCtrl.text, onLog: _addLog);
      await _svc.disconnect(onLog: _addLog);
      _addLog(
        'Bluetooth disconnected (EspBluFi order). '
        'Set up Wi‑Fi next in a new BLE session.',
      );
      if (!mounted) return;
      setState(() => _phase = _SendPhase.success);
    } catch (e) {
      _addLog('ERROR: $e');
      if (mounted) setState(() => _phase = _SendPhase.warning);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _readResponse() async {
    _addLog('Listening for BLE notify responses (already subscribed)…');
  }

  void _clearLog() => setState(() => _log.clear());

  Future<void> _continueAfterSuccess(BuildContext context) async {
    final paired = DeviceStore.instance.cached;
    final nav = Navigator.of(context);
    if (paired != null && !paired.isWifiProvisioned) {
      nav.pop();
      await Future<void>.delayed(Duration.zero);
      if (!context.mounted) return;
      await nav.push<PairingNavResult>(
        MaterialPageRoute<PairingNavResult>(
          builder: (_) => const WifiProvisionScreen(firstTimeSetup: true),
        ),
      );
      return;
    }
    nav.pop();
    PairingFlowNav.onComplete(const PairingNavResult(success: true, openSendGallery: true));
  }

  Future<void> _copyLog() async {
    await Clipboard.setData(ClipboardData(text: _log.join('\n')));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Log copied')),
    );
  }

  bool get _canSend =>
      _selected != null &&
      _jsonError == null &&
      !_busy &&
      _svc.connectedDevice != null;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final connectedName = _selected?.name ?? widget.initialDeviceName;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Frame Config'),
        actions: [
          if (_log.isNotEmpty)
            IconButton(
              tooltip: 'Copy log',
              onPressed: _copyLog,
              icon: const Icon(Icons.copy_outlined),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _phaseBanner(cs),
          if (DeviceStore.instance.cached == null) ...[
            const SizedBox(height: 10),
            Card(
              color: Colors.orange.shade50,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Pair a frame first, then complete Wi‑Fi setup before sending MQTT config.',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ),
          ] else if (!DeviceStore.instance.cached!.isWifiProvisioned) ...[
            const SizedBox(height: 10),
            Card(
              color: Colors.orange.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Wi‑Fi must be set up before the frame can reach MQTT and download photos. '
                  'Use Setup WiFi on the scan screen first, then send MQTT config.',
                  style: TextStyle(fontSize: 13, color: cs.onSurface),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text('Devices', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Row(
            children: [
              FilledButton.tonalIcon(
                onPressed: _scanning || _connecting ? null : _startScan,
                icon: _scanning
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.bluetooth_searching),
                label: Text(_scanning ? 'Scanning…' : 'Scan'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  connectedName != null
                      ? 'Connected to $connectedName'
                      : _scanning
                          ? 'Scanning…'
                          : 'Disconnected',
                  style: TextStyle(
                    color: connectedName != null
                        ? Colors.green.shade700
                        : cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._devices.map((d) {
            final sel =
                _selected?.device.remoteId.str == d.device.remoteId.str;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              color: sel ? cs.primaryContainer.withValues(alpha: 0.35) : null,
              child: ListTile(
                leading: Icon(
                  sel ? Icons.bluetooth_connected : Icons.bluetooth,
                  color: sel ? Colors.green : cs.primary,
                ),
                title: Text(
                  d.name,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
                subtitle: Text('RSSI ${d.rssi} · ${d.mac}'),
                trailing: FilledButton(
                  onPressed: _connecting ? null : () => _connectDevice(d),
                  child: Text(sel ? 'Connected' : 'Connect'),
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
          Text('Config JSON', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          TextField(
            controller: _configCtrl,
            maxLines: 14,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderSide: BorderSide(
                  color: _jsonError != null ? cs.error : cs.outline,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(
                  color: _jsonError != null ? cs.error : cs.outline,
                ),
              ),
              errorText: _jsonError,
              helperText: '${_configCtrl.text.length} characters',
            ),
            onChanged: (_) => _validateJson(),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () {
              _resetConfigEditor();
              _addLog('Reset config to default');
            },
            child: const Text('Reset to Default'),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _canSend ? _sendConfig : null,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send),
            label: const Text('Send Config'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _selected == null ? null : _readResponse,
            icon: const Icon(Icons.hearing),
            label: const Text('Read Response'),
          ),
          TextButton(onPressed: _clearLog, child: const Text('Clear log')),
          const SizedBox(height: 8),
          Text('Log', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Container(
            height: 180,
            decoration: BoxDecoration(
              border: Border.all(color: cs.outlineVariant),
              borderRadius: BorderRadius.circular(8),
              color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
            ),
            child: ListView.builder(
              controller: _logScroll,
              padding: const EdgeInsets.all(10),
              itemCount: _log.length,
              itemBuilder: (_, i) => Text(
                _log[i],
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  color: cs.onSurface,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _phaseBanner(ColorScheme cs) {
    switch (_phase) {
      case _SendPhase.sending:
        return _banner(
          cs,
          icon: const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          title: 'Sending config to frame…',
          color: cs.primaryContainer,
        );
      case _SendPhase.waitingOnline:
        return _banner(
          cs,
          icon: const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          title: 'Config sent! Waiting for frame to connect…',
          color: cs.primaryContainer,
        );
      case _SendPhase.success:
        return _banner(
          cs,
          icon: const Icon(Icons.check_circle, color: Colors.green, size: 28),
          title: 'Frame configured successfully!',
          color: Colors.green.shade50,
          child: FilledButton(
            onPressed: () => _continueAfterSuccess(context),
            child: const Text('Continue setup →'),
          ),
        );
      case _SendPhase.warning:
        return _banner(
          cs,
          icon: Icon(
            Icons.warning_amber_rounded,
            color: Colors.orange.shade800,
            size: 28,
          ),
          title: 'Config was sent but frame hasn\'t connected yet.',
          subtitle: 'Try: 1) Power cycle the frame  2) Check WiFi password',
          color: Colors.orange.shade50,
          child: Row(
            children: [
              TextButton(
                onPressed: () => setState(() => _phase = _SendPhase.idle),
                child: const Text('Try Again'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _canSend ? _sendConfig : null,
                child: const Text('Send Config Again'),
              ),
            ],
          ),
        );
      case _SendPhase.idle:
        return const SizedBox.shrink();
    }
  }

  Widget _banner(
    ColorScheme cs, {
    required Widget icon,
    required String title,
    String? subtitle,
    required Color color,
    Widget? child,
  }) {
    return Card(
      color: color,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                icon,
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (child != null) ...[const SizedBox(height: 12), child],
          ],
        ),
      ),
    );
  }
}
