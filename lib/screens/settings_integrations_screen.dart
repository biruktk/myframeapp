import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../config/vps_defaults.dart';
import '../l10n/app_strings.dart';
import '../services/family_group_store.dart';
import '../services/usage_metrics_store.dart';
import '../settings/app_settings.dart';

class SettingsIntegrationsScreen extends StatefulWidget {
  const SettingsIntegrationsScreen({super.key});

  @override
  State<SettingsIntegrationsScreen> createState() => _SettingsIntegrationsScreenState();
}

class _SettingsIntegrationsScreenState extends State<SettingsIntegrationsScreen> {
  late bool _googleConnected;
  late bool _icloudConnected;
  late bool _homeAssistantConnected;
  late bool _googleAutoSync;
  var _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    final app = AppSettingsScope.of(context);
    _googleConnected = app.googlePhotosConnected;
    _icloudConnected = app.iCloudConnected;
    _homeAssistantConnected = app.homeAssistantConnected;
    _googleAutoSync = app.googlePhotosAutoSync;
    _loaded = true;
  }

  Future<void> _save() async {
    final app = AppSettingsScope.of(context);
    await app.setIntegrationsPrefs(
      googleConnected: _googleConnected,
      iCloud: _icloudConnected,
      homeAssistant: _homeAssistantConnected,
      googleAutoSync: _googleAutoSync,
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(s.integrations)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(s.connectedServices, style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Card(
            child: Column(
              children: [
                _IntegrationTile(
                  icon: Icons.photo_library_outlined,
                  title: s.googlePhotos,
                  subtitle: _googleConnected ? s.syncAutomatically : s.notConnected,
                  connected: _googleConnected,
                  onPressed: () async {
                    setState(() => _googleConnected = !_googleConnected);
                    await _save();
                  },
                ),
                _IntegrationTile(
                  icon: Icons.cloud_outlined,
                  title: s.iCloudPhotos,
                  subtitle: _icloudConnected ? s.syncAutomatically : s.notConnected,
                  connected: _icloudConnected,
                  onPressed: () async {
                    setState(() => _icloudConnected = !_icloudConnected);
                    await _save();
                  },
                ),
                _IntegrationTile(
                  icon: Icons.home_outlined,
                  title: s.homeAssistant,
                  subtitle: _homeAssistantConnected ? s.connected : s.notConnected,
                  connected: _homeAssistantConnected,
                  onPressed: () async {
                    setState(() => _homeAssistantConnected = !_homeAssistantConnected);
                    await _save();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(s.autoSyncTitle, style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              leading: CircleAvatar(
                radius: 18,
                backgroundColor: cs.surfaceContainerHighest,
                foregroundColor: cs.primary,
                child: const Icon(Icons.sync, size: 18),
              ),
              title: Text(s.googlePhotosSync),
              subtitle: Text(s.dailyAtNine),
              trailing: Switch.adaptive(
                value: _googleAutoSync,
                onChanged: (v) async {
                  setState(() => _googleAutoSync = v);
                  await _save();
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () async {
              final app = AppSettingsScope.of(context);
              await FamilyGroupStore.instance.ensureLoaded(ownerDisplayName: () {
                final name = app.profileName.trim();
                if (name.isNotEmpty) return name;
                final mail = app.accountEmail.trim();
                if (mail.isNotEmpty) return mail.split('@').first;
                return 'You';
              });
              if (!context.mounted) return;
              final g = FamilyGroupStore.instance;
              final inviteUrl =
                  'https://${VpsDefaults.hostnameInk}/join?code=${Uri.encodeComponent(g.inviteCode)}';
              final subject = '${s.inviteFamily} · ${g.familyName}';
              await Share.share(
                s.familyInviteShareBody(g.familyName, g.inviteCode, inviteUrl),
                subject: subject,
              );
              if (!context.mounted) return;
              await UsageMetricsStore.instance.markShareEvent();
            },
            icon: const Icon(Icons.ios_share),
            label: Text(s.shareInviteLink),
          ),
        ],
      ),
    );
  }
}

class _IntegrationTile extends StatelessWidget {
  const _IntegrationTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.connected,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool connected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: cs.surfaceContainerHighest,
        foregroundColor: cs.primary,
        child: Icon(icon, size: 18),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: connected
          ? Text(s.connected, style: TextStyle(color: cs.primary, fontWeight: FontWeight.w600))
          : OutlinedButton(
              onPressed: onPressed,
              child: Text(s.connectLabel),
            ),
      onTap: connected ? onPressed : null,
    );
  }
}
