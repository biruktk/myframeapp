import 'dart:async';

import 'package:flutter/material.dart';

import '../config/dropbox_config.dart';
import '../l10n/app_strings.dart';
import '../services/dropbox_service.dart';
import '../services/google_drive_service.dart';
import '../settings/app_settings.dart';
import '../widgets/integration_brand_logo.dart';

class SettingsIntegrationsScreen extends StatefulWidget {
  const SettingsIntegrationsScreen({super.key});

  @override
  State<SettingsIntegrationsScreen> createState() => _SettingsIntegrationsScreenState();
}

class _SettingsIntegrationsScreenState extends State<SettingsIntegrationsScreen> {
  var _driveBusy = false;
  var _dropboxBusy = false;

  @override
  void initState() {
    super.initState();
    unawaited(GoogleDriveService.instance.loadPrefs());
    unawaited(DropboxService.instance.loadPrefs());
  }

  Future<void> _toggleGoogleDrive() async {
    setState(() => _driveBusy = true);
    try {
      if (GoogleDriveService.instance.isConnected) {
        await GoogleDriveService.instance.disconnect();
        final app = AppSettingsScope.of(context);
        if (app.photoStorageBackend == 'google_drive') {
          await app.setPhotoStorageBackend('vps');
        }
      } else {
        await GoogleDriveService.instance.connect();
        if (GoogleDriveService.instance.isConnected && mounted) {
          await AppSettingsScope.of(context).setPhotoStorageBackend('google_drive');
        }
      }
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      final s = AppStrings.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.integrationErrorDrive('$e'))),
      );
    } finally {
      if (mounted) setState(() => _driveBusy = false);
    }
  }

  Future<void> _toggleDropbox() async {
    setState(() => _dropboxBusy = true);
    try {
      if (DropboxService.instance.isConnected) {
        await DropboxService.instance.disconnect();
        final app = AppSettingsScope.of(context);
        if (app.photoStorageBackend == 'dropbox') {
          await app.setPhotoStorageBackend('vps');
        }
      } else {
        if (!DropboxConfig.isConfigured) {
          if (!mounted) return;
          final s = AppStrings.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(s.dropboxKeyMissing)),
          );
          return;
        }
        await DropboxService.instance.connect();
        if (!mounted) return;
        final s = AppStrings.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.dropboxBrowserSignIn)),
        );
      }
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      final s = AppStrings.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.integrationErrorDropbox('$e'))),
      );
    } finally {
      if (mounted) setState(() => _dropboxBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final cs = Theme.of(context).colorScheme;
    final driveOn = GoogleDriveService.instance.isConnected;
    final dropboxOn = DropboxService.instance.isConnected;

    return Scaffold(
      appBar: AppBar(title: Text(s.integrations)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            s.integrationsCloudStorageIntro,
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant, height: 1.4),
          ),
          const SizedBox(height: 14),
          Card(
            child: Column(
              children: [
                _IntegrationTile(
                  logo: const IntegrationBrandLogo.googleDrive(size: 28),
                  title: 'Google Drive',
                  subtitle: driveOn ? s.integrationsDriveConnectedSub : s.notConnected,
                  connected: driveOn,
                  busy: _driveBusy,
                  onPressed: () => unawaited(_toggleGoogleDrive()),
                ),
                const Divider(height: 1, indent: 72),
                _IntegrationTile(
                  logo: const IntegrationBrandLogo.dropbox(size: 28),
                  title: 'Dropbox',
                  subtitle: dropboxOn
                      ? (DropboxService.instance.accountName ?? s.integrationsDropboxConnectedSub)
                      : s.notConnected,
                  connected: dropboxOn,
                  busy: _dropboxBusy,
                  onPressed: () => unawaited(_toggleDropbox()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IntegrationTile extends StatelessWidget {
  const _IntegrationTile({
    required this.logo,
    required this.title,
    required this.subtitle,
    required this.connected,
    required this.onPressed,
    this.busy = false,
  });

  final Widget logo;
  final String title;
  final String subtitle;
  final bool connected;
  final VoidCallback onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: cs.surfaceContainerHighest,
        child: logo,
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(subtitle),
      ),
      trailing: busy
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : connected
              ? TextButton(onPressed: onPressed, child: Text(s.disconnectLabel))
              : OutlinedButton(
                  onPressed: onPressed,
                  child: Text(s.connectLabel),
                ),
      onTap: busy ? null : onPressed,
    );
  }
}
