import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../services/device_store.dart';
import '../services/frame_forget_service.dart';
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
import 'settings_pairing_screen.dart';
import 'settings_firmware_screen.dart';
import '../widgets/connect_frame_dialog.dart';
import 'device_management_screen.dart';
import 'playlist_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  PairedFrame? _paired;

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

  Future<void> _forgetFrame() async {
    final paired = _paired;
    if (paired == null) return;
    final s = AppStrings.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(s.removePairingTitle),
        content: Text(s.removePairingBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(s.cancel)),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(s.remove)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await FrameForgetService.instance.forgetFrame(paired.deviceId);
    await _load();
  }

  Future<void> _requireFrame(VoidCallback whenPaired) async {
    if (_paired == null) {
      await showConnectFrameFirstDialog(context);
      return;
    }
    whenPaired();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final app = AppSettingsScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final appearanceSubtitle =
        '${s.themeModeLabel(app.themeMode)} · ${s.accentLabel(app.accent)}';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: Text(s.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          _SectionLabel(text: s.settingsSectionAccount),
          _SettingsRow(
            icon: Icons.person_outline,
            title: s.account,
            subtitle: s.accountSub,
            onTap: () {
              Navigator.push<void>(
                context,
                MaterialPageRoute<void>(builder: (_) => const SettingsAccountScreen()),
              );
            },
          ),
          _SectionLabel(text: s.settingsSectionApplication),
          _SettingsRow(
            icon: Icons.bluetooth_connected,
            title: s.framePairing,
            subtitle: _paired == null
                ? s.scanDeviceBody
                : '${_paired!.listDisplayTitle(s)}\n${_paired!.deviceId}${_paired!.apiUrl != null ? '\n${_paired!.apiUrl}' : ''}',
            onTap: () async {
              await Navigator.push<void>(
                context,
                MaterialPageRoute<void>(builder: (_) => const SettingsPairingScreen()),
              );
              await _load();
            },
          ),
          _SettingsRow(
            icon: Icons.playlist_play_outlined,
            title: s.playlist,
            subtitle: s.yourPlaylists,
            onTap: () {
              Navigator.push<void>(
                context,
                MaterialPageRoute<void>(builder: (_) => const PlaylistScreen()),
              );
            },
          ),
          _SettingsRow(
            icon: Icons.palette_outlined,
            title: s.appearanceTitle,
            subtitle: appearanceSubtitle,
            onTap: () {
              Navigator.push<void>(
                context,
                MaterialPageRoute<void>(builder: (_) => const SettingsAppearanceScreen()),
              );
            },
          ),
          _SettingsRow(
            icon: Icons.notifications_none,
            title: s.notifications,
            subtitle: s.notificationsSub,
            onTap: () {
              Navigator.push<void>(
                context,
                MaterialPageRoute<void>(builder: (_) => const SettingsNotificationsScreen()),
              );
            },
          ),
          _SettingsRow(
            icon: Icons.language,
            title: s.language,
            subtitle: _languageSubtitle(app, s),
            onTap: () {
              Navigator.push<void>(
                context,
                MaterialPageRoute<void>(builder: (_) => const SettingsLanguageScreen()),
              );
            },
          ),
          _SettingsRow(
            icon: Icons.link,
            title: s.integrations,
            subtitle: s.integrationsSub,
            onTap: () {
              Navigator.push<void>(
                context,
                MaterialPageRoute<void>(builder: (_) => const SettingsIntegrationsScreen()),
              );
            },
          ),
          _SettingsRow(
            icon: Icons.display_settings_outlined,
            title: s.displaySettingsScreenTitle,
            subtitle: s.displaySettingsSub,
            onTap: () {
              Navigator.push<void>(
                context,
                MaterialPageRoute<void>(builder: (_) => const SettingsDisplayScreen()),
              );
            },
          ),
          _SettingsRow(
            icon: Icons.tune,
            title: s.appPreferences,
            subtitle: s.appPreferencesSub,
            onTap: () {
              Navigator.push<void>(
                context,
                MaterialPageRoute<void>(builder: (_) => const SettingsAppPreferencesScreen()),
              );
            },
          ),
          _SettingsRow(
            icon: Icons.bug_report_outlined,
            title: s.debugModeTitle,
            subtitle: s.debugModeSub,
            onTap: () {
              Navigator.push<void>(
                context,
                MaterialPageRoute<void>(builder: (_) => const SettingsDebugScreen()),
              );
            },
          ),
          const SizedBox(height: 10),
          _SectionLabel(text: s.settingsSectionFrame),
          Material(
            color: cs.surface,
            borderRadius: BorderRadius.circular(16),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.delete_outline, color: cs.error),
                  title: Text(s.settingsForgetFrameTitle),
                  subtitle: Text(s.settingsForgetFrameSub),
                  onTap: () => _requireFrame(_forgetFrame),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _SettingsRow(
            icon: Icons.sd_card_outlined,
            title: s.deviceInfo,
            subtitle: s.deviceInfoSub,
            onTap: () {
              Navigator.push<void>(
                context,
                MaterialPageRoute<void>(builder: (_) => const DeviceManagementScreen()),
              );
            },
          ),
          _SettingsRow(
            icon: Icons.system_update_alt_outlined,
            title: s.firmwareUpdateTitle,
            subtitle: s.firmwareUpdateSub,
            onTap: () {
              Navigator.push<void>(
                context,
                MaterialPageRoute<void>(builder: (_) => const SettingsFirmwareScreen()),
              );
            },
          ),
          _SectionLabel(text: s.settingsSectionAi),
          _SettingsRow(
            icon: Icons.auto_awesome,
            title: s.aiGenerateNavTitle,
            subtitle: s.aiGenerateSub,
            onTap: () {
              Navigator.push<void>(
                context,
                MaterialPageRoute<void>(builder: (_) => const SettingsAiGenerateScreen()),
              );
            },
          ),
          _SettingsRow(
            icon: Icons.notifications_paused_outlined,
            title: s.aiSilentModeTitle,
            subtitle: s.comingSoonLabel,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(s.aiSilentModeComingSoon)),
              );
            },
          ),
          _SectionLabel(text: s.settingsSectionHelp),
          _SettingsRow(
            icon: Icons.help_outline,
            title: s.helpSettingsTitle,
            subtitle: s.helpSettingsSub,
            onTap: () {
              Navigator.push<void>(
                context,
                MaterialPageRoute<void>(builder: (_) => const SettingsHelpScreen()),
              );
            },
          ),
          if (app.debugModeEnabled)
            _SettingsRow(
              icon: Icons.receipt_long_outlined,
              title: s.operationLog,
              subtitle: s.operationLogSub,
              onTap: () {
                Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const SettingsLogScreen()),
                );
              },
            ),
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
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 6),
      child: Text(text, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: cs.primary)),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(icon, color: cs.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  trailing!,
                  const SizedBox(width: 4),
                ],
                Icon(Icons.chevron_right, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

