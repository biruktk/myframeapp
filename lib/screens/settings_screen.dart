import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../services/device_store.dart';
import '../settings/app_settings.dart';
import 'settings_account_screen.dart';
import 'settings_notifications_screen.dart';
import 'settings_language_screen.dart';
import 'settings_appearance_screen.dart';
import 'settings_integrations_screen.dart';
import 'settings_ai_generate_screen.dart';
import 'settings_app_preferences_screen.dart';
import 'settings_help_screen.dart';
import 'settings_log_screen.dart';
import 'settings_debug_screen.dart';
import 'settings_display_screen.dart';
import 'device_details_screen.dart';
import 'playlist_screen.dart';

const _red = Color(0xFFE53935);

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  PairedFrame? _paired;
  var _sleepEnabled = true;
  var _autoOtaEnabled = true;
  TimeOfDay _sleepStart = const TimeOfDay(hour: 23, minute: 0);
  TimeOfDay _sleepEnd = const TimeOfDay(hour: 7, minute: 0);
  final _firmwareVersion = 'v0.5.0';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await DeviceStore.instance.load();
    if (mounted) setState(() => _paired = DeviceStore.instance.cached);
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
    if (_paired == null) return s.scanDeviceBody;
    final title = _paired!.listDisplayTitle(s);
    final id = _paired!.deviceId;
    return '$title · ${id.length > 12 ? '${id.substring(0, 12)}...' : id}';
  }

  String _formatTime(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final p = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:${t.minute.toString().padLeft(2, '0')} $p';
  }

  String get _sleepSubtitle {
    if (!_sleepEnabled) return 'Disabled';
    return '${_formatTime(_sleepStart)} – ${_formatTime(_sleepEnd)}';
  }

  String get _otaSubtitle {
    return 'Version $_firmwareVersion · Auto-check ${_autoOtaEnabled ? 'on' : 'off'}';
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

  void _showSleepPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sleep Mode Schedule',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Sleep Start Time'),
              trailing: Text(
                _formatTime(_sleepStart),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              onTap: () async {
                final picked = await showTimePicker(context: ctx, initialTime: _sleepStart);
                if (picked != null) {
                  setState(() => _sleepStart = picked);
                  if (ctx.mounted) Navigator.pop(ctx);
                }
              },
            ),
            ListTile(
              title: const Text('Wake Up Time'),
              trailing: Text(
                _formatTime(_sleepEnd),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              onTap: () async {
                final picked = await showTimePicker(context: ctx, initialTime: _sleepEnd);
                if (picked != null) {
                  setState(() => _sleepEnd = picked);
                  if (ctx.mounted) Navigator.pop(ctx);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _checkOtaUpdate() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Firmware Update'),
        content: Text('Current version is $_firmwareVersion. Your device firmware is up to date.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(color: Color(0xFFE53935))),
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
    final appearanceSub =
        '${s.themeModeLabel(app.themeMode)} · ${s.accentLabel(app.accent)}';

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      appBar: AppBar(
        title: Text(s.settingsTitle, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          _sectionHeader(s.settingsSectionAccount),
          _buildGroup([
            _tile(
              icon: Icons.person_outline,
              title: s.account,
              subtitle: s.accountSub,
              onTap: () => Navigator.push<void>(
                context, MaterialPageRoute<void>(builder: (_) => const SettingsAccountScreen()),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          _sectionHeader(s.settingsSectionFrame),
          _buildGroup([
            _tile(
              icon: Icons.bluetooth_connected,
              title: s.framePairing,
              subtitle: _pairingSubtitle(s),
              onTap: () async {
                await Navigator.push<void>(
                  context, MaterialPageRoute<void>(builder: (_) => const DeviceDetailsScreen()),
                );
                await _load();
              },
            ),
            _divider,
            _tile(
              icon: Icons.display_settings_outlined,
              title: s.displaySettingsScreenTitle,
              subtitle: s.displaySettingsSub,
              onTap: () => Navigator.push<void>(
                context, MaterialPageRoute<void>(builder: (_) => const SettingsDisplayScreen()),
              ),
            ),
            _divider,
            _tile(
              icon: Icons.bedtime_outlined,
              title: 'Sleep Mode',
              subtitle: _sleepSubtitle,
              trailing: Switch.adaptive(
                value: _sleepEnabled,
                activeTrackColor: _red,
                onChanged: (v) => setState(() => _sleepEnabled = v),
              ),
              onTap: _sleepEnabled ? _showSleepPicker : null,
            ),
            _divider,
            _tile(
              icon: Icons.system_update_alt,
              title: 'OTA Firmware Update',
              subtitle: _otaSubtitle,
              trailing: Switch.adaptive(
                value: _autoOtaEnabled,
                activeTrackColor: _red,
                onChanged: (v) => setState(() => _autoOtaEnabled = v),
              ),
              onTap: _checkOtaUpdate,
            ),
          ]),
          const SizedBox(height: 16),
          _sectionHeader(s.settingsSectionApplication),
          _buildGroup([
            _tile(
              icon: Icons.playlist_play,
              title: s.playlist,
              subtitle: s.yourPlaylists,
              onTap: () => Navigator.push<void>(
                context, MaterialPageRoute<void>(builder: (_) => const PlaylistScreen()),
              ),
            ),
            _divider,
            _tile(
              icon: Icons.palette_outlined,
              title: s.appearanceTitle,
              subtitle: appearanceSub,
              onTap: () => Navigator.push<void>(
                context, MaterialPageRoute<void>(builder: (_) => const SettingsAppearanceScreen()),
              ),
            ),
            _divider,
            _tile(
              icon: Icons.notifications_none,
              title: s.notifications,
              subtitle: s.notificationsSub,
              onTap: () => Navigator.push<void>(
                context, MaterialPageRoute<void>(builder: (_) => const SettingsNotificationsScreen()),
              ),
            ),
            _divider,
            _tile(
              icon: Icons.language,
              title: s.language,
              subtitle: _languageSubtitle(app, s),
              onTap: () => Navigator.push<void>(
                context, MaterialPageRoute<void>(builder: (_) => const SettingsLanguageScreen()),
              ),
            ),
            _divider,
            _tile(
              icon: Icons.link,
              title: s.integrations,
              subtitle: s.integrationsSub,
              onTap: () => Navigator.push<void>(
                context, MaterialPageRoute<void>(builder: (_) => const SettingsIntegrationsScreen()),
              ),
            ),
            _divider,
            _tile(
              icon: Icons.tune,
              title: s.appPreferences,
              subtitle: s.appPreferencesSub,
              onTap: () => Navigator.push<void>(
                context, MaterialPageRoute<void>(builder: (_) => const SettingsAppPreferencesScreen()),
              ),
            ),
            _divider,
            _tile(
              icon: Icons.auto_awesome,
              title: s.aiGenerateNavTitle,
              subtitle: s.aiGenerateSub,
              onTap: () => Navigator.push<void>(
                context, MaterialPageRoute<void>(builder: (_) => const SettingsAiGenerateScreen()),
              ),
            ),
            _divider,
            _tile(
              icon: Icons.bug_report_outlined,
              title: s.debugModeTitle,
              subtitle: s.debugModeSub,
              onTap: () => Navigator.push<void>(
                context, MaterialPageRoute<void>(builder: (_) => const SettingsDebugScreen()),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          _sectionHeader(s.settingsSectionHelp),
          _buildGroup([
            _tile(
              icon: Icons.help_outline,
              title: s.helpSettingsTitle,
              subtitle: s.helpSettingsSub,
              onTap: () => Navigator.push<void>(
                context, MaterialPageRoute<void>(builder: (_) => const SettingsHelpScreen()),
              ),
            ),
            if (app.debugModeEnabled) ...[
              _divider,
              _tile(
                icon: Icons.receipt_long_outlined,
                title: s.operationLog,
                subtitle: s.operationLogSub,
                onTap: () => Navigator.push<void>(
                  context, MaterialPageRoute<void>(builder: (_) => const SettingsLogScreen()),
                ),
              ),
            ],
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

Widget _sectionHeader(String title) {
  return Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 6),
    child: Text(
      title,
      style: const TextStyle(
        color: _red,
        fontWeight: FontWeight.bold,
        fontSize: 13,
      ),
    ),
  );
}

Widget _buildGroup(List<Widget> children) {
  return Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE0E0E0), width: 0.5),
    ),
    child: Column(children: children),
  );
}

Widget _tile({
  required IconData icon,
  required String title,
  required String subtitle,
  Widget? trailing,
  VoidCallback? onTap,
}) {
  return ListTile(
    dense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
    leading: Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: _red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: _red, size: 18),
    ),
    title: Text(
      title,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
    ),
    subtitle: Text(
      subtitle,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 11, color: Colors.grey),
    ),
    trailing: trailing ?? const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
    onTap: onTap,
  );
}

const _divider = Divider(height: 1, indent: 48, endIndent: 12, color: Color(0xFFEEEEEE));



