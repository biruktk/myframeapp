import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../services/device_store.dart';

class FrameProfileSetupScreen extends StatefulWidget {
  const FrameProfileSetupScreen({super.key});

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
    await DeviceStore.instance.saveFrameProfile(
      frameName: _nameCtrl.text,
      orientation: _orientation,
    );
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.frameProfileTitle)),
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
    );
  }
}
