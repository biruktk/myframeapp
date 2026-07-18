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

  final bool requiredSetup;

  @override
  State<FrameProfileSetupScreen> createState() => _FrameProfileSetupScreenState();
}

class _FrameProfileSetupScreenState extends State<FrameProfileSetupScreen> {
  final _nameCtrl = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final paired = DeviceStore.instance.cached;
    _nameCtrl.text = paired?.frameName?.trim() ?? '';
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
        orientation: 'portrait',
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
        const SnackBar(content: Text('Could not save frame profile. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.requiredSetup,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Name Your Frame'),
          centerTitle: true,
          automaticallyImplyLeading: !widget.requiredSetup,
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Icon(
                Icons.check_circle_outline,
                size: 64,
                color: const Color(0xFFE5252A),
              ),
              const SizedBox(height: 20),
              Text(
                'Your Frame is Connected!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Give your frame a name and start sending photos.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _nameCtrl,
                style: const TextStyle(fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'e.g. Living Room Frame',
                  prefixIcon: const Icon(Icons.edit_outlined),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
              ),
              const Spacer(flex: 1),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _busy ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFE5252A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100),
                    ),
                    elevation: 4,
                    shadowColor: const Color(0xFFE5252A).withValues(alpha: 0.25),
                  ),
                  child: const Text(
                    'Start Sending',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
