import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/frame_playback_profile.dart';
import '../services/app_diag_log.dart';
import '../services/device_store.dart';
import '../services/frame_settings_store.dart';
import '../settings/app_settings.dart';
import '../widgets/playlist_controls_widget.dart';

/// Frame Profile — the global playback defaults owned by the frame
/// (interval / playback order / duration) that uploaded photos inherit.
///
/// Replaces the per-album playback configuration as the single unified source
/// for a frame's slideshow behavior.
class FrameSettingsScreen extends StatefulWidget {
  const FrameSettingsScreen({super.key});

  @override
  State<FrameSettingsScreen> createState() => _FrameSettingsScreenState();
}

class _FrameSettingsScreenState extends State<FrameSettingsScreen> {
  FramePlaybackProfile _profile = FramePlaybackProfile.externalShareDefaults;
  PairedFrame? _paired;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      await DeviceStore.instance.load();
      final paired = DeviceStore.instance.cached;
      final profile = await FrameSettingsStore.instance.load(paired);
      if (!mounted) return;
      setState(() {
        _paired = paired;
        _profile = profile;
        _loading = false;
      });
    } catch (e, st) {
      AppDiagLog.verbose('[FrameSettings] load failed: $e\n$st');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final s = AppStrings.of(context);
    final app = AppSettingsScope.of(context);
    final paired = _paired;
    if (paired == null || _saving) return;
    setState(() => _saving = true);
    try {
      await FrameSettingsStore.instance.save(paired, _profile);
      unawaited(
        FrameSettingsStore.instance.pushProfileToFrame(
          paired: paired,
          profile: _profile,
          userAuthToken: app.authToken,
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s.frameProfileSaved),
          duration: const Duration(seconds: 2),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          s.frameProfileNavTitle,
          style: TextStyle(fontWeight: FontWeight.bold, color: cs.onSurface),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _paired == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      s.frameProfileNeedsFrame,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: cs.onSurfaceVariant, height: 1.4),
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  children: [
                    Text(
                      s.frameProfileIntro,
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    PlaylistControlsWidget(
                      selectedIntervalSeconds: _profile.intervalSeconds,
                      onIntervalChanged: (seconds) => setState(
                        () => _profile = _profile.copyWith(
                          intervalMinutes: seconds ~/ 60,
                        ),
                      ),
                      selectedStrategy: _profile.strategy,
                      onStrategyChanged: (v) => setState(
                        () => _profile = _profile.copyWith(
                          playbackMode: v == 2
                              ? FramePlaybackProfile.modeRandom
                              : FramePlaybackProfile.modeSequential,
                        ),
                      ),
                      selectedDurationHours: _profile.durationHours,
                      onDurationChanged: (v) => setState(
                        () => _profile = _profile.copyWith(durationHours: v),
                      ),
                    ),
                    const SizedBox(height: 28),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(s.saveLabel),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
