import 'dart:async';

import 'package:flutter/material.dart';

import '../config/feature_flags.dart';
import '../l10n/app_strings.dart';
import '../services/device_store.dart';
import '../services/frame_api_client.dart';
import '../services/ota_update_store.dart';
import '../services/sleep_mode_store.dart';
import '../settings/app_settings.dart';
import 'settings_account_screen.dart';
import 'settings_language_screen.dart';
// import 'settings_appearance_screen.dart';
// import 'settings_integrations_screen.dart';
import 'settings_ai_generate_screen.dart';
import 'settings_app_preferences_screen.dart';
import 'settings_help_screen.dart';
import 'settings_log_screen.dart';
import 'settings_debug_screen.dart';
import 'device_discovery_screen.dart';

import 'playlist_screen.dart';
import 'sleep_settings_screen.dart';
import 'frame_settings_screen.dart';

const _red = Color(0xFFE53935);

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  var _sleepEnabled = false;
  var _autoOtaEnabled = false;
  TimeOfDay _sleepStart = SleepModeStore.defaultStart;
  TimeOfDay _sleepEnd = SleepModeStore.defaultEnd;
  var _firmwareVersion = '--';
  var _hasUpdate = false;
  var _sleepReady = false;
  var _otaReady = false;

  @override
  void initState() {
    super.initState();
    DeviceStore.instance.revision.addListener(_onFramesChanged);
    unawaited(_loadDeviceToggles());
  }

  @override
  void dispose() {
    DeviceStore.instance.revision.removeListener(_onFramesChanged);
    super.dispose();
  }

  void _onFramesChanged() {
    // Newly connected frame auto-enables sleep / OTA when unset.
    unawaited(_loadDeviceToggles());
  }

  Future<void> _loadDeviceToggles() async {
    await Future.wait([
      SleepModeStore.instance.resolveForUi(),
      OtaUpdateStore.instance.resolveForUi(),
    ]);
    if (!mounted) return;
    final sleep = SleepModeStore.instance;
    final ota = OtaUpdateStore.instance;
    // Keep AppSettings OTA flags aligned with the resolved UI value.
    final app = AppSettingsScope.of(context);
    if (app.automaticFrameFirmwareUpdates != ota.enabled) {
      await app.setAutomaticFrameFirmwareUpdates(ota.enabled);
    }
    if (!mounted) return;
    setState(() {
      _sleepEnabled = sleep.enabled;
      _sleepStart = sleep.startTime;
      _sleepEnd = sleep.endTime;
      _sleepReady = true;
      _autoOtaEnabled = ota.enabled;
      _otaReady = true;
    });
    unawaited(_loadFirmwareInfo());
  }

  /// Fetch the frame's dynamic firmware version + OTA availability.
  Future<void> _loadFirmwareInfo() async {
    await DeviceStore.instance.load();
    final frames = DeviceStore.instance.pairedFrames;
    final paired = frames.isEmpty ? DeviceStore.instance.cached : frames.first;
    if (paired == null) return;
    final mac = DeviceStore.macForPairedFrame(paired);
    if (mac == null || mac.isEmpty) return;
    final api = FrameApiClient();
    try {
      final st = await api.fetchFrameStatus(
        mac: mac,
        pairingToken: paired.resolvedPairingToken,
      );
      if (st == null || !mounted) return;
      final fw = st.firmwareVersion;
      setState(() {
        _firmwareVersion = (fw == null || fw.isEmpty)
            ? '--'
            : (fw.startsWith('v') ? fw : 'v$fw');
        _hasUpdate = st.hasUpdate;
      });
    } catch (_) {
    } finally {
      api.close();
    }
  }

  String _languageSubtitle(AppSettings app, AppStrings s) {
    return switch (app.languageCode) {
      null => s.languageSystem,
      'en' => s.languageEnglish,
      'zh' => s.languageChinese,
      'es' => s.languageSpanish,
      'fr' => s.languageFrench,
      'de' => s.languageGerman,
      'ja' => s.languageJapanese,
      _ => s.languageEnglish,
    };
  }

  String _pairingSubtitle(AppStrings s) {
    return s.scanDeviceTitle;
  }

  String _formatTime(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final p = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:${t.minute.toString().padLeft(2, '0')} $p';
  }

  String _sleepSubtitle(AppStrings s) {
    if (!_sleepEnabled) return s.disabledLabel;
    return '${_formatTime(_sleepStart)} – ${_formatTime(_sleepEnd)}';
  }

  String _otaSubtitle(AppStrings s) {
    final auto = _autoOtaEnabled ? s.otaAutoCheckOn : s.otaAutoCheckOff;
    if (_hasUpdate) return '${s.firmwareUpdateAvailable} ($_firmwareVersion · $auto)';
    return '${s.firmwareCurrentVersion} $_firmwareVersion · $auto';
  }

  Future<void> _onSleepToggle(bool value) async {
    setState(() => _sleepEnabled = value);
    await SleepModeStore.instance.setEnabled(value);
    unawaited(SleepModeStore.instance.pushConfigToFrame());
  }

  Future<void> _onOtaToggle(bool value) async {
    setState(() => _autoOtaEnabled = value);
    await OtaUpdateStore.instance.setEnabled(value);
    if (!mounted) return;
    await AppSettingsScope.of(context).setAutomaticFrameFirmwareUpdates(value);
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final s = AppStrings.of(context);
    final go = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(s.signOutConfirmTitle),
        content: Text(s.signOutConfirmBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(s.cancel)),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(s.signOutLabel)),
        ],
      ),
    );
    if (go != true || !context.mounted) return;
    await AppSettingsScope.of(context).setSignedIn(value: false);
  }

  void _openSleepSettings() {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => const SleepSettingsScreen()),
    );
  }

  void _checkOtaUpdate() {
    final s = AppStrings.of(context);
    final body = _hasUpdate
        ? '${s.firmwareUpdateAvailable} ${s.firmwareCurrentVersion} $_firmwareVersion.'
        : '${s.firmwareCurrentVersion} $_firmwareVersion. ${s.firmwareUpToDate}';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.firmwareUpdateTitle),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(s.okLabel, style: const TextStyle(color: Color(0xFFE53935))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final app = AppSettingsScope.of(context);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(s.settingsTitle, style: TextStyle(fontWeight: FontWeight.bold, color: cs.onSurface)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          _sectionHeader(s.settingsSectionAccount, cs),
          _buildGroup(cs, [
            _tile(
              context: context,
              icon: Icons.person_outline,
              title: s.account,
              subtitle: s.accountSub,
              onTap: () => Navigator.push<void>(
                context, MaterialPageRoute<void>(builder: (_) => const SettingsAccountScreen()),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          _sectionHeader(s.settingsSectionFrame, cs),
          _buildGroup(cs, [
            _tile(
              context: context,
              icon: Icons.add_circle_outline,
              title: s.framePairing,
              subtitle: _pairingSubtitle(s),
              onTap: () async {
                await Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const DeviceDiscoveryScreen(),
                  ),
                );
              },
            ),
_tile(
              context: context,
              icon: Icons.tune_rounded,
              title: s.frameProfileNavTitle,
              subtitle: s.frameProfileNavSub,
              onTap: () => Navigator.push<void>(
                context, MaterialPageRoute<void>(builder: (_) => FrameSettingsScreen()),
              ),
            ),
            _divider(cs),
            _tile(
              context: context,
              icon: Icons.bedtime_outlined,
              title: s.sleepMode,
              subtitle: _sleepReady ? _sleepSubtitle(s) : '…',
              trailing: Switch.adaptive(
                value: _sleepEnabled,
                activeTrackColor: _red,
                onChanged: _sleepReady
                    ? (v) => unawaited(_onSleepToggle(v))
                    : null,
              ),
              onTap: _sleepEnabled ? _openSleepSettings : null,
            ),
            _divider(cs),
            _tile(
              context: context,
              icon: Icons.system_update_alt,
              title: s.otaFirmwareUpdate,
              subtitle: _otaReady ? _otaSubtitle(s) : '…',
              trailing: Switch.adaptive(
                value: _autoOtaEnabled,
                activeTrackColor: _red,
                onChanged: _otaReady
                    ? (v) => unawaited(_onOtaToggle(v))
                    : null,
              ),
              onTap: _checkOtaUpdate,
            ),
          ]),
          const SizedBox(height: 16),
          _sectionHeader(s.settingsSectionApplication, cs),
          _buildGroup(cs, [
            _tile(
              context: context,
              icon: Icons.language,
              title: s.language,
              subtitle: _languageSubtitle(app, s),
              onTap: () => Navigator.push<void>(
                context, MaterialPageRoute<void>(builder: (_) => const SettingsLanguageScreen()),
              ),
            ),
            _tile(
              context: context,
              icon: Icons.tune,
              title: s.appPreferences,
              subtitle: s.appPreferencesSub,
              onTap: () => Navigator.push<void>(
                context, MaterialPageRoute<void>(builder: (_) => const SettingsAppPreferencesScreen()),
              ),
            ),
            if (FeatureFlags.enableAIFeatures) ...[
              _divider(cs),
              _tile(
                context: context,
                icon: Icons.auto_awesome,
                title: s.aiGenerateNavTitle,
                subtitle: s.aiGenerateSub,
                onTap: () => Navigator.push<void>(
                  context, MaterialPageRoute<void>(builder: (_) => const SettingsAiGenerateScreen()),
                ),
              ),
            ],
          ]),
          const SizedBox(height: 16),
          _sectionHeader(s.settingsSectionHelp, cs),
          _buildGroup(cs, [
            _tile(
              context: context,
              icon: Icons.help_outline,
              title: s.helpSettingsTitle,
              subtitle: s.helpSettingsSub,
              onTap: () => Navigator.push<void>(
                context, MaterialPageRoute<void>(builder: (_) => const SettingsHelpScreen()),
              ),
            ),
            _divider(cs),
            // _tile(
            //   context: context,
            //   icon: Icons.bug_report,
            //   title: 'Debug',
            //   subtitle: app.debugModeEnabled ? 'Debug mode active' : 'Enable debug features',
            //   onTap: () => Navigator.push<void>(
            //     context, MaterialPageRoute<void>(builder: (_) => const SettingsDebugScreen()),
            //   ),
            // ),
            // if (app.debugModeEnabled) ...[
            //   _divider(cs),
            //   _tile(
            //     context: context,
            //     icon: Icons.receipt_long_outlined,
            //     title: s.operationLog,
            //     subtitle: s.operationLogSub,
            //     onTap: () => Navigator.push<void>(
            //       context, MaterialPageRoute<void>(builder: (_) => const SettingsLogScreen()),
            //     ),
            //   ),
            // ],
          ]),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _confirmSignOut(context),
              icon: const Icon(Icons.logout),
              style: OutlinedButton.styleFrom(
                foregroundColor: cs.error,
                side: BorderSide(color: cs.error),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              label: Text(s.signOutLabel),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

Widget _sectionHeader(String title, ColorScheme cs) {
  return Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 6),
    child: Text(
      title,
      style: TextStyle(
        color: cs.primary,
        fontWeight: FontWeight.bold,
        fontSize: 13,
      ),
    ),
  );
}

Widget _buildGroup(ColorScheme cs, List<Widget> children) {
  return Container(
    decoration: BoxDecoration(
      color: cs.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: cs.outlineVariant, width: 0.5),
    ),
    child: Column(children: children),
  );
}

Widget _tile({
  required BuildContext context,
  required IconData icon,
  required String title,
  required String subtitle,
  Widget? trailing,
  VoidCallback? onTap,
}) {
  final cs = Theme.of(context).colorScheme;
  return ListTile(
    dense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
    leading: Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: cs.primary, size: 18),
    ),
    title: Text(
      title,
      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cs.onSurface),
    ),
    subtitle: Text(
      subtitle,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
    ),
    trailing: trailing ?? Icon(Icons.chevron_right, size: 18, color: cs.onSurfaceVariant),
    onTap: onTap,
  );
}

Widget _divider(ColorScheme cs) => Divider(height: 1, indent: 48, endIndent: 12, color: cs.outlineVariant);


