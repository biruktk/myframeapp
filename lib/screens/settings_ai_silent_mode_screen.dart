import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../l10n/app_strings.dart';
import '../services/ai_silent_mode_store.dart';
import '../services/gallery_image_cache.dart';
import '../services/image_sanitizer.dart';

/// AI Silent Mode — layout aligned to product spec (stats + toggles + person list).
class SettingsAiSilentModeScreen extends StatefulWidget {
  const SettingsAiSilentModeScreen({super.key});

  @override
  State<SettingsAiSilentModeScreen> createState() => _SettingsAiSilentModeScreenState();
}

class _SettingsAiSilentModeScreenState extends State<SettingsAiSilentModeScreen> {
  final _store = AiSilentModeStore.instance;
  final _apiKeysCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _hydrate();
  }

  Future<void> _hydrate() async {
    await _store.load();
    _apiKeysCtrl.text = _store.silentApiKeys;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _apiKeysCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    _store.silentApiKeys = _apiKeysCtrl.text.trim();
    await _store.save();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.of(context).saveSettings)));
  }

  Future<void> _addPerson() async {
    final s = AppStrings.of(context);
    final nick = TextEditingController();
    DateTime bday = DateTime(1990, 1, 1);
    final img = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (img == null || !mounted) return;
    final safePath = await ImageSanitizer.sanitize(img.path);
    final photoPath = await GalleryImageCache.persistFromPath(
      (safePath == null || safePath.isEmpty) ? img.path : safePath,
      normalizeJpeg: false,
    );
    if (photoPath == null || !mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (context, setD) => AlertDialog(
          title: Text(s.nicknameLabel),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nick, decoration: InputDecoration(labelText: s.nicknameLabel)),
              const SizedBox(height: 12),
              ListTile(
                title: Text(s.joinFamilyBirthdayLabel),
                subtitle: Text('${bday.year}-${bday.month.toString().padLeft(2, '0')}-${bday.day.toString().padLeft(2, '0')}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: bday,
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                  );
                  if (d != null) setD(() => bday = d);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: Text(s.cancel)),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(s.nextLabel)),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final id = '${DateTime.now().millisecondsSinceEpoch}';
    _store.people.add(
      SilentPersonEntry(
        id: id,
        nickname: nick.text.trim().isEmpty ? 'Member' : nick.text.trim(),
        birthdayIso: bday.toIso8601String().split('T').first,
        photoPath: photoPath,
      ),
    );
    setState(() {});
  }

  void _removePerson(String id) {
    _store.people.removeWhere((e) => e.id == id);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(s.aiSilentModeTitle),
        actions: [
          IconButton(icon: const Icon(Icons.info_outline), onPressed: () {}),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          Text(s.aiSilentIntro, style: TextStyle(color: cs.onSurfaceVariant, height: 1.45)),
          const SizedBox(height: 16),
          Card(
            child: SwitchListTile.adaptive(
              value: _store.silentModeEnabled,
              onChanged: (v) => setState(() => _store.silentModeEnabled = v),
              secondary: Icon(Icons.notifications_off_outlined, color: cs.primary),
              title: Row(
                children: [
                  Expanded(child: Text(s.silentModeToggleTitle, style: const TextStyle(fontWeight: FontWeight.w700))),
                  if (_store.silentModeEnabled)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(6)),
                      child: Text('ON', style: TextStyle(color: cs.onPrimary, fontSize: 11, fontWeight: FontWeight.w800)),
                    ),
                ],
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(s.silentModeToggleSub),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Icon(Icons.groups_2_outlined, color: cs.primary),
              const SizedBox(width: 8),
              Expanded(child: Text(s.personIndexingTitle, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
              TextButton(onPressed: _addPerson, child: Text(s.addFamilyMember)),
            ],
          ),
          Text(s.personIndexingSub, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13, height: 1.35)),
          const SizedBox(height: 10),
          for (final p in _store.people)
            Card(
              child: ListTile(
                leading: CircleAvatar(child: Text(p.nickname.isNotEmpty ? p.nickname[0].toUpperCase() : '?')),
                title: Text(p.nickname),
                subtitle: Text(p.birthdayIso),
                trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _removePerson(p.id)),
              ),
            ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _addPerson,
            child: Text(s.addAnotherFamilyMember),
          ),
          const SizedBox(height: 22),
          Card(
            child: SwitchListTile.adaptive(
              value: _store.backgroundScreening,
              onChanged: (v) => setState(() => _store.backgroundScreening = v),
              secondary: Icon(Icons.auto_awesome, color: cs.primary),
              title: Text(s.aiBackgroundScreening, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(s.aiBackgroundScreeningSub),
            ),
          ),
          if (_store.backgroundScreening) ...[
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  SwitchListTile.adaptive(
                    value: _store.emotionFiltering,
                    onChanged: (v) => setState(() => _store.emotionFiltering = v),
                    secondary: Icon(Icons.sentiment_satisfied_alt, color: cs.primary),
                    title: Text(s.emotionFilteringTitle),
                    subtitle: Text(s.emotionFilteringSub),
                  ),
                  SwitchListTile.adaptive(
                    value: _store.qualityCheck,
                    onChanged: (v) => setState(() => _store.qualityCheck = v),
                    secondary: Icon(Icons.hd_outlined, color: cs.primary),
                    title: Text(s.qualityCheckTitle),
                    subtitle: Text(s.qualityCheckSub),
                  ),
                  SwitchListTile.adaptive(
                    value: _store.eventBasedPushing,
                    onChanged: (v) => setState(() => _store.eventBasedPushing = v),
                    secondary: Icon(Icons.event, color: cs.primary),
                    title: Text(s.eventPushingTitle),
                    subtitle: Text(s.eventPushingSub),
                  ),
                  SwitchListTile.adaptive(
                    value: _store.quietHoursInSilent,
                    onChanged: (v) => setState(() => _store.quietHoursInSilent = v),
                    title: Text(s.quietHoursSilentLabel),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: TextField(
                      controller: _apiKeysCtrl,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: s.apiKeysSilentLabel,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          ListTile(
            leading: Icon(Icons.bar_chart, color: cs.primary),
            title: Text(s.aiScreeningPreview, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(s.aiScreeningPreviewSub),
            trailing: const Icon(Icons.chevron_right),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
              child: Row(
                children: [
                  _StatCol(cs, '${_store.statsProcessed}', s.statPhotosProcessed),
                  _StatCol(cs, '${_store.statsPushed}', s.statPhotosPushed),
                  _StatCol(cs, '${_store.statsPositivePct}%', s.statPositiveEmotion),
                  _StatCol(cs, '${_store.statsQualityPct}%', s.statHighQuality),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_outlined),
            label: Text(s.saveSettings),
          ),
        ),
      ),
    );
  }
}

class _StatCol extends StatelessWidget {
  const _StatCol(this.cs, this.value, this.label);

  final ColorScheme cs;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: cs.primary)),
          const SizedBox(height: 4),
          Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant, height: 1.2)),
        ],
      ),
    );
  }
}
