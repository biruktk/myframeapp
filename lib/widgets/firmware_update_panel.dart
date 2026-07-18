import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../services/device_store.dart';
import '../services/firmware_update_service.dart';
import '../settings/app_settings.dart';

/// Manual frame firmware check + install (backend MQTT OTA).
class FirmwareUpdatePanel extends StatefulWidget {
  const FirmwareUpdatePanel({super.key, this.compact = false});

  final bool compact;

  @override
  State<FirmwareUpdatePanel> createState() => _FirmwareUpdatePanelState();
}

class _FirmwareUpdatePanelState extends State<FirmwareUpdatePanel> {
  final _service = FirmwareUpdateService();
  FirmwareCheckResponse? _check;
  String? _error;
  bool _busy = false;
  Timer? _poll;

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  String? get _deviceId {
    final paired = DeviceStore.instance.cached;
    if (paired == null) return null;
    final id = paired.resolvedFrameTargetId.trim();
    return id.isEmpty ? null : id;
  }

  String? get _bleMac =>
      DeviceStore.instance.pairedFrameMac ?? DeviceStore.instance.cached?.bleNamePrefix;

  String? get _displayName {
    final paired = DeviceStore.instance.cached;
    if (paired == null) return null;
    final name = paired.frameName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return paired.bleNamePrefix?.trim();
  }

  Future<void> _runCheck({bool silent = false}) async {
    final deviceId = _deviceId;
    final token = AppSettingsScope.of(context).authToken.trim();
    final s = AppStrings.of(context);
    if (deviceId == null || deviceId.isEmpty) {
      setState(() {
        _error = s.firmwareNoDevice;
        _check = null;
      });
      return;
    }
    if (token.isEmpty) {
      setState(() {
        _error = s.firmwareSignInRequired;
        _check = null;
      });
      return;
    }
    if (!silent) {
      setState(() {
        _busy = true;
        _error = null;
      });
    }
    try {
      final result = await _service.checkUpdate(
        deviceId: deviceId,
        bearerToken: token,
        bleMac: _bleMac,
        displayName: _displayName,
      );
      if (!mounted) return;
      setState(() {
        _check = result;
        _busy = false;
        _error = null;
      });
      if (result.isUpdating) {
        _startPolling();
      } else {
        _poll?.cancel();
      }
    } on FirmwareUpdateException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = s.firmwareCheckErrorMessage(e.code);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString();
      });
    }
  }

  void _startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 8), (_) => _runCheck(silent: true));
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runCheck());
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final cs = Theme.of(context).colorScheme;
    final check = _check;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(widget.compact ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.memory_outlined, color: cs.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.firmwareUpdateTitle, style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(s.firmwareUpdateSub, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant, height: 1.35)),
                    ],
                  ),
                ),
              ],
            ),
            if (_busy && check == null) ...[
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator()),
            ],
            if (check != null) ...[
              const SizedBox(height: 14),
              _InfoRow(label: s.firmwareCurrentVersion, value: 'v${check.currentVersion}'),
              _InfoRow(label: s.firmwareLatestVersion, value: 'v${check.latestVersion}'),
              if (!check.frameOnline)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(s.firmwareFrameOffline, style: TextStyle(color: cs.error, fontSize: 13)),
                ),
              if (check.updateAvailable)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(s.firmwareUpdateAvailable, style: TextStyle(color: cs.primary, fontWeight: FontWeight.w600)),
                )
              else if (check.isSuccess || !check.updateAvailable)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(s.firmwareUpToDate, style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w600)),
                ),
              if (check.isUpdating)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(s.firmwareUpdating, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                ),
              if (check.isFailed)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(s.firmwareUpdateFailed, style: TextStyle(color: cs.error, fontSize: 13)),
                ),
              if (check.releaseNotes.trim().isNotEmpty && check.updateAvailable) ...[
                const SizedBox(height: 10),
                Text(check.releaseNotes, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant, height: 1.4)),
              ],
            ],
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: TextStyle(color: cs.error, fontSize: 13)),
            ],
            const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'monospace')),
        ],
      ),
    );
  }
}
