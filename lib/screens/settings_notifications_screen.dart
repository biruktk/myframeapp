import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../settings/app_settings.dart';

class SettingsNotificationsScreen extends StatefulWidget {
  const SettingsNotificationsScreen({super.key});

  @override
  State<SettingsNotificationsScreen> createState() => _SettingsNotificationsScreenState();
}

class _SettingsNotificationsScreenState extends State<SettingsNotificationsScreen> {
  late bool _birthdayReminders;
  late int _birthdayLeadDays;
  late bool _photoDelivered;
  late bool _newFamilyMember;
  late bool _likedPhotos;
  late bool _frameOffline;
  late bool _quietHoursEnabled;
  late String _quietStart;
  late String _quietEnd;
  var _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    final app = AppSettingsScope.of(context);
    _birthdayReminders = app.notifyBirthdayReminders;
    _birthdayLeadDays = app.birthdayReminderLeadDays;
    _photoDelivered = app.notifyPhotoDelivered;
    _newFamilyMember = app.notifyFamilyActivity;
    _likedPhotos = app.notifyLikedPhotos;
    _frameOffline = app.notifyFrameOffline;
    _quietHoursEnabled = app.quietHoursEnabled;
    _quietStart = app.quietHoursStart;
    _quietEnd = app.quietHoursEnd;
    _loaded = true;
  }

  Future<void> _save() async {
    final app = AppSettingsScope.of(context);
    await app.setAdvancedNotificationPrefs(
      birthdayReminders: _birthdayReminders,
      birthdayLeadDays: _birthdayLeadDays,
      photoDelivered: _photoDelivered,
      newFamilyMember: _newFamilyMember,
      likedPhotos: _likedPhotos,
      frameOffline: _frameOffline,
      quietEnabled: _quietHoursEnabled,
      quietStart: _quietStart,
      quietEnd: _quietEnd,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppStrings.of(context).saveLabel)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(s.notifications)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(s.notificationsSectionReminders, style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Card(
            child: Column(
              children: [
                _NotificationRow(
                  icon: Icons.cake_outlined,
                  title: s.notifyBirthdayReminders,
                  subtitle: s.birthdayLeadDays(_birthdayLeadDays),
                  value: _birthdayReminders,
                  onChanged: (v) => setState(() => _birthdayReminders = v),
                ),
                if (_birthdayReminders)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: DropdownButtonFormField<int>(
                      value: _birthdayLeadDays,
                      decoration: InputDecoration(
                        labelText: s.notifyBirthdayLeadLabel,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: const [1, 2, 3, 7]
                          .map((d) => DropdownMenuItem<int>(value: d, child: Text('$d')))
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _birthdayLeadDays = v);
                      },
                    ),
                  ),
                _NotificationRow(
                  icon: Icons.cloud_upload_outlined,
                  title: s.notifyPhotoDelivered,
                  subtitle: s.notifyUploadCompleteSub,
                  value: _photoDelivered,
                  onChanged: (v) => setState(() => _photoDelivered = v),
                ),
                _NotificationRow(
                  icon: Icons.wifi_off_outlined,
                  title: s.notifyFrameOffline,
                  subtitle: s.notifyDeviceOfflineSub,
                  value: _frameOffline,
                  onChanged: (v) => setState(() => _frameOffline = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(s.notificationsSectionFamily, style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Card(
            child: Column(
              children: [
                _NotificationRow(
                  icon: Icons.person_add_alt_1_outlined,
                  title: s.notifyNewFamilyMember,
                  subtitle: s.notifyNewFamilyMemberSub,
                  value: _newFamilyMember,
                  onChanged: (v) => setState(() => _newFamilyMember = v),
                ),
                _NotificationRow(
                  icon: Icons.favorite_border,
                  title: s.notifyLikedPhotos,
                  subtitle: s.notifyLikedPhotosSub,
                  value: _likedPhotos,
                  onChanged: (v) => setState(() => _likedPhotos = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(s.notificationsSectionQuietHours, style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Card(
            child: Column(
              children: [
                _NotificationRow(
                  icon: Icons.nights_stay_outlined,
                  title: s.quietHoursDndTitle,
                  subtitle: '$_quietStart - $_quietEnd',
                  value: _quietHoursEnabled,
                  onChanged: (v) => setState(() => _quietHoursEnabled = v),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: _TimeField(
                          label: s.quietHoursStartLabel,
                          value: _quietStart,
                          enabled: _quietHoursEnabled,
                          onTap: () async {
                            final t = await showTimePicker(
                              context: context,
                              initialTime: _parse(_quietStart),
                            );
                            if (t == null) return;
                            setState(() => _quietStart = _fmt(t));
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _TimeField(
                          label: s.quietHoursEndLabel,
                          value: _quietEnd,
                          enabled: _quietHoursEnabled,
                          onTap: () async {
                            final t = await showTimePicker(
                              context: context,
                              initialTime: _parse(_quietEnd),
                            );
                            if (t == null) return;
                            setState(() => _quietEnd = _fmt(t));
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
            child: Text(
              s.notificationsQuietHoursTzFootnote,
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, height: 1.35),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: Text(s.saveLabel),
          ),
        ],
      ),
    );
  }

  TimeOfDay _parse(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return const TimeOfDay(hour: 22, minute: 0);
    final h = int.tryParse(parts[0]) ?? 22;
    final m = int.tryParse(parts[1]) ?? 0;
    return TimeOfDay(hour: h.clamp(0, 23), minute: m.clamp(0, 59));
  }

  String _fmt(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final String value;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          child: Text(value),
        ),
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: cs.surfaceContainerHighest,
        foregroundColor: cs.primary,
        child: Icon(icon, size: 18),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Switch.adaptive(
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}
