import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../l10n/app_strings.dart';
import '../services/app_diag_log.dart';
import '../services/device_store.dart';

class FrameProfileSetupScreen extends StatefulWidget {
  const FrameProfileSetupScreen({
    super.key,
    this.requiredSetup = false,
  });

  /// First-time Wi‑Fi setup: user must tap Continue (no accidental back-out).
  final bool requiredSetup;

  @override
  State<FrameProfileSetupScreen> createState() => _FrameProfileSetupScreenState();
}

class _FrameProfileSetupScreenState extends State<FrameProfileSetupScreen> {
  final _nameCtrl = TextEditingController();
  String _orientation = 'portrait';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final paired = DeviceStore.instance.cached;
    _nameCtrl.text = paired?.frameName?.trim() ?? '';
    _orientation = paired?.frameOrientation == 'landscape' ? 'landscape' : 'portrait';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      var name = _nameCtrl.text.trim();
      if (name.isEmpty) {
        name = AppStrings.of(context).frameDefaultDisplayName;
      }
      await DeviceStore.instance.saveFrameProfile(
        frameName: name,
        orientation: _orientation,
      );
      if (!mounted) return;
      setState(() => _busy = false);
      await SchedulerBinding.instance.endOfFrame;
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e, st) {
      AppDiagLog.verbose('[Profile] save failed: $e\n$st');
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save frame profile. Try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return PopScope(
      canPop: !widget.requiredSetup,
      child: Scaffold(
      appBar: AppBar(
        title: Text(s.frameProfileTitle),
        automaticallyImplyLeading: !widget.requiredSetup,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(s.frameProfileBody),
          const SizedBox(height: 14),
          TextField(
            controller: _nameCtrl,
            decoration: InputDecoration(
              labelText: s.frameNameLabel,
              hintText: s.frameDefaultDisplayName,
              prefixIcon: const Icon(Icons.edit_outlined),
            ),
          ),
          const SizedBox(height: 14),
          Text(s.frameOrientationLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
          RadioListTile<String>(
            value: 'portrait',
            groupValue: _orientation,
            onChanged: (v) => setState(() => _orientation = v ?? 'portrait'),
            title: Text(s.frameOrientationPortrait),
          ),
          RadioListTile<String>(
            value: 'landscape',
            groupValue: _orientation,
            onChanged: (v) => setState(() => _orientation = v ?? 'landscape'),
            title: Text(s.frameOrientationLandscape),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(s.finishSetupButton),
          ),
        ],
      ),
    ),
    );
  }
}
