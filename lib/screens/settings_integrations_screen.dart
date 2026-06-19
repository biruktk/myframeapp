import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../services/google_photos_service.dart';
import '../services/icloud_photos_service.dart';
import '../settings/app_settings.dart';
import '../widgets/integration_brand_logo.dart';

class SettingsIntegrationsScreen extends StatefulWidget {
  const SettingsIntegrationsScreen({super.key});

  @override
  State<SettingsIntegrationsScreen> createState() =>
      _SettingsIntegrationsScreenState();
}

class _SettingsIntegrationsScreenState
    extends State<SettingsIntegrationsScreen> {
  var _googlePhotosBusy = false;
  var _icloudBusy = false;

  @override
  void initState() {
    super.initState();
    unawaited(GooglePhotosService.instance.loadPrefs());
    unawaited(ICloudPhotosService.instance.loadPrefs());
  }

  Future<void> _toggleGooglePhotos() async {
    setState(() => _googlePhotosBusy = true);
    try {
      final app = AppSettingsScope.of(context);
      if (GooglePhotosService.instance.isConnected) {
        await GooglePhotosService.instance.disconnect();
        if (app.photoStorageBackend == 'google_photos') {
          await app.setPhotoStorageBackend('vps');
        }
      } else {
        await GooglePhotosService.instance.connect();
        if (GooglePhotosService.instance.isConnected && mounted) {
          await app.setPhotoStorageBackend('google_photos');
        }
      }
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      final s = AppStrings.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.integrationErrorGooglePhotos('$e'))),
      );
    } finally {
      if (mounted) setState(() => _googlePhotosBusy = false);
    }
  }

  Future<void> _toggleICloudPhotos() async {
    setState(() => _icloudBusy = true);
    try {
      final app = AppSettingsScope.of(context);
      if (ICloudPhotosService.instance.isConnected) {
        await ICloudPhotosService.instance.disconnect();
        if (app.photoStorageBackend == 'icloud_photos') {
          await app.setPhotoStorageBackend('vps');
        }
      } else {
        if (!ICloudPhotosService.instance.isAvailable) {
          if (!mounted) return;
          final s = AppStrings.of(context);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(s.icloudPhotosUnavailable)));
          return;
        }
        await ICloudPhotosService.instance.connect();
        if (ICloudPhotosService.instance.isConnected && mounted) {
          await app.setPhotoStorageBackend('icloud_photos');
        }
      }
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      final s = AppStrings.of(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(s.integrationErrorICloud('$e'))));
    } finally {
      if (mounted) setState(() => _icloudBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final cs = Theme.of(context).colorScheme;
    final googlePhotosOn = GooglePhotosService.instance.isConnected;
    final icloudOn = ICloudPhotosService.instance.isConnected;
    final showICloud = ICloudPhotosService.instance.isAvailable;

    return Scaffold(
      appBar: AppBar(title: Text(s.integrations)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            s.integrationsCloudStorageIntro,
            style: TextStyle(
              fontSize: 13,
              color: cs.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Column(
              children: [
                _IntegrationTile(
                  logo: const IntegrationBrandLogo.googlePhotos(size: 28),
                  title: 'Google Photos',
                  subtitle: googlePhotosOn
                      ? s.integrationsGooglePhotosConnectedSub
                      : s.notConnected,
                  connected: googlePhotosOn,
                  busy: _googlePhotosBusy,
                  onPressed: () => unawaited(_toggleGooglePhotos()),
                ),
                if (showICloud) ...[
                  const Divider(height: 1, indent: 72),
                  _IntegrationTile(
                    logo: const IntegrationBrandLogo.icloud(size: 28),
                    title: 'iCloud Photos',
                    subtitle: icloudOn
                        ? s.integrationsICloudConnectedSub
                        : s.notConnected,
                    connected: icloudOn,
                    busy: _icloudBusy,
                    onPressed: () => unawaited(_toggleICloudPhotos()),
                  ),
                ],
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
          : OutlinedButton(onPressed: onPressed, child: Text(s.connectLabel)),
      onTap: busy ? null : onPressed,
    );
  }
}
