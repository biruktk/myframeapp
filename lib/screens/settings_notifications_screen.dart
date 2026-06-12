import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../services/in_app_notification_store.dart';

/// In-app activity feed — what you did inside MyFrame (not OS push toggles).
class SettingsNotificationsScreen extends StatefulWidget {
  const SettingsNotificationsScreen({super.key});

  @override
  State<SettingsNotificationsScreen> createState() => _SettingsNotificationsScreenState();
}

class _SettingsNotificationsScreenState extends State<SettingsNotificationsScreen> {
  @override
  void initState() {
    super.initState();
    InAppNotificationStore.instance.ensureLoaded();
    InAppNotificationStore.instance.addListener(_onStore);
  }

  @override
  void dispose() {
    InAppNotificationStore.instance.removeListener(_onStore);
    super.dispose();
  }

  void _onStore() {
    if (mounted) setState(() {});
  }

  IconData _iconFor(String name) {
    return switch (name) {
      'photo' => Icons.photo_outlined,
      'cake' => Icons.cake_outlined,
      'family' => Icons.groups_outlined,
      'offline' => Icons.wifi_off_outlined,
      'cloud' => Icons.cloud_done_outlined,
      _ => Icons.notifications_none_outlined,
    };
  }

  String _formatWhen(DateTime dt, AppStrings s) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return s.justNow;
    if (diff.inHours < 1) return s.minutesAgo(diff.inMinutes);
    if (diff.inDays < 1) return s.hoursAgo(diff.inHours);
    if (diff.inDays < 7) return s.daysAgo(diff.inDays);
    return '${dt.month}/${dt.day}/${dt.year}';
  }

  ({String title, String body}) _localized(InAppNotification n, AppStrings s) {
    final p = n.params;
    switch (n.kind) {
      case 'photo':
        return (
          title: s.inAppNotifPhotoSentTitle,
          body: s.inAppNotifPhotoSentBody(p['frameName'] ?? ''),
        );
      case 'cloud':
        return (
          title: s.inAppNotifCloudUploadTitle,
          body: s.inAppNotifCloudUploadBody(
            p['provider'] ?? '',
            p['fileName'] ?? '',
          ),
        );
      case 'birthday':
        final name = p['name'] ?? '';
        final days = int.tryParse(p['daysUntil'] ?? '') ?? 0;
        return (
          title: s.inAppNotifBirthdayTitle,
          body: s.inAppNotifBirthdayBody(name, days),
        );
      case 'offline':
        return (
          title: s.inAppNotifOfflineTitle,
          body: s.inAppNotifOfflineBody(p['frameName'] ?? ''),
        );
      case 'family':
        return (
          title: s.inAppNotifFamilyTitle,
          body: p['message']?.isNotEmpty == true ? p['message']! : s.inAppNotifFamilyBody,
        );
      default:
        if (n.title.isNotEmpty || n.body.isNotEmpty) {
          return (title: n.title, body: n.body);
        }
        return (title: s.inAppNotifOtherTitle, body: s.inAppNotifOtherBody);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final cs = Theme.of(context).colorScheme;
    final items = InAppNotificationStore.instance.items;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.notifications),
        actions: [
          if (items.isNotEmpty)
            TextButton(
              onPressed: () async {
                await InAppNotificationStore.instance.clearAll();
              },
              child: Text(s.notificationsClear),
            ),
        ],
      ),
      body: items.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.notifications_none_outlined, size: 48, color: cs.outline),
                    const SizedBox(height: 16),
                    Text(
                      s.notificationsEmptyTitle,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      s.notificationsEmptyBody,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: cs.onSurfaceVariant, height: 1.4),
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final n = items[i];
                final text = _localized(n, s);
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                    leading: CircleAvatar(
                      backgroundColor: cs.primary.withValues(alpha: 0.12),
                      foregroundColor: cs.primary,
                      child: Icon(_iconFor(n.iconName), size: 20),
                    ),
                    title: Text(
                      text.title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(text.body, style: TextStyle(color: cs.onSurfaceVariant)),
                    ),
                    trailing: Text(
                      _formatWhen(n.timestamp, s),
                      style: TextStyle(fontSize: 11, color: cs.outline),
                    ),
                    isThreeLine: true,
                  ),
                );
              },
            ),
    );
  }
}
