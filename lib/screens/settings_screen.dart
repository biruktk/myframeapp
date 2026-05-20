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
import 'settings_ai_silent_mode_screen.dart';
import 'settings_app_preferences_screen.dart';
import 'settings_pro_screen.dart';
import 'settings_help_screen.dart';
import 'settings_log_screen.dart';
import 'settings_debug_screen.dart';
import 'settings_display_screen.dart';
import 'settings_pairing_screen.dart';
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
          Material(
            color: cs.surface,
            borderRadius: BorderRadius.circular(16),
            child: ListTile(
              onTap: () async {
                await Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const SettingsPairingScreen()),
                );
                await _load();
              },
              leading: Icon(Icons.bluetooth_connected, color: cs.primary),
              title: Text(s.framePairing, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(
                _paired == null
                    ? s.scanDeviceBody
                    : '${_paired!.listDisplayTitle(s)}\n${_paired!.deviceId}${_paired!.apiUrl != null ? '\n${_paired!.apiUrl}' : ''}',
              ),
              trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400),
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
            subtitle: s.displaySettingsIntro,
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
            subtitle: s.aiSilentIntro,
            onTap: () {
              Navigator.push<void>(
                context,
                MaterialPageRoute<void>(builder: (_) => const SettingsAiSilentModeScreen()),
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
          _SettingsRow(
            icon: Icons.workspace_premium,
            title: s.plansAndStorageTitle,
            subtitle: s.plansAndStorageSub,
            onTap: () {
              Navigator.push<void>(
                context,
                MaterialPageRoute<void>(builder: (_) => const SettingsProScreen()),
              );
            },
            trailing: const _PlansProBadge(),
          ),
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

/// Same purple PRO pill as `badge-pro` in the HTML mock.
class _PlansProBadge extends StatelessWidget {
  const _PlansProBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: const LinearGradient(
          colors: [Color(0xFFAF52DE), Color(0xFF6B4EE6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Text(
        'PRO',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}
