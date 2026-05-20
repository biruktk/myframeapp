import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/send_overlay_options.dart';
import '../services/send_albums_store.dart';

/// Result of the Send flow bottom sheet (album + display options).
class SendAlbumSheetResult {
  const SendAlbumSheetResult({
    required this.overlay,
    required this.displaySeconds,
    this.locationLine,
    this.addToAlbumId,
    this.newAlbumName,
  });

  final SendOverlayOptions overlay;
  final int displaySeconds;
  final String? locationLine;
  final String? addToAlbumId;
  final String? newAlbumName;
}

Future<SendAlbumSheetResult?> showSendAlbumSettingsSheet(
  BuildContext context, {
  required List<String> photoPaths,
}) {
  return showModalBottomSheet<SendAlbumSheetResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _SendAlbumSheetBody(photoPaths: photoPaths),
  );
}

class _SendAlbumSheetBody extends StatefulWidget {
  const _SendAlbumSheetBody({required this.photoPaths});

  final List<String> photoPaths;

  @override
  State<_SendAlbumSheetBody> createState() => _SendAlbumSheetBodyState();
}

class _SendAlbumSheetBodyState extends State<_SendAlbumSheetBody> {
  int _displaySeconds = 10;
  bool _customOn = false;
  bool _cityWeatherOn = false;
  bool _holidayOn = false;
  final _customCtrl = TextEditingController();
  String? _addToAlbumId;
  String? _addToAlbumName;
  String? _newAlbumName;

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  Future<void> _chooseExistingAlbum(AppStrings s) async {
    await SendAlbumsStore.instance.load();
    final albums = SendAlbumsStore.instance.albums;
    if (!mounted) return;
    if (albums.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.addToAlbumNoAlbumsYet)));
      return;
    }
    final id = await showDialog<String>(
      context: context,
      builder: (c) => SimpleDialog(
        title: Text(s.addToExistingAlbum),
        children: [
          for (final a in albums)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(c, '${a.id}\u001f${a.name}'),
              child: Text(a.name),
            ),
        ],
      ),
    );
    if (id != null && id.contains('\u001f')) {
      final parts = id.split('\u001f');
      setState(() {
        _addToAlbumId = parts[0];
        _addToAlbumName = parts.length > 1 ? parts[1] : null;
        _newAlbumName = null;
      });
    }
  }

  Future<void> _createAlbumDialog(AppStrings s) async {
    final nameCtrl = TextEditingController();
    try {
      final name = await showDialog<String>(
        context: context,
        builder: (c) => StatefulBuilder(
          builder: (c, setD) {
            return AlertDialog(
              title: Text(s.createNewAlbum),
              content: TextField(
                controller: nameCtrl,
                autofocus: true,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(labelText: s.newAlbumNameHint),
                onChanged: (_) => setD(() {}),
                onSubmitted: (v) {
                  final t = v.trim();
                  if (t.isNotEmpty) Navigator.pop(c, t);
                },
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(c), child: Text(s.cancel)),
                FilledButton(
                  onPressed: nameCtrl.text.trim().isEmpty ? null : () => Navigator.pop(c, nameCtrl.text.trim()),
                  child: Text(s.nextLabel),
                ),
              ],
            );
          },
        ),
      );
      if (name != null && name.isNotEmpty) {
        setState(() {
          _newAlbumName = name;
          _addToAlbumId = null;
          _addToAlbumName = null;
        });
      }
    } finally {
      nameCtrl.dispose();
    }
  }

  void _submit(AppStrings s) {
    final cityLine = _cityWeatherOn ? s.showCityWeatherDemo : null;
    final overlay = SendOverlayOptions(
      showDate: false,
      showLocation: _cityWeatherOn,
      showGreeting: _holidayOn,
      customText: _customOn ? _customCtrl.text : '',
      greetingCustom: _holidayOn ? s.holidayGreetingLine : null,
    );
    Navigator.pop(
      context,
      SendAlbumSheetResult(
        overlay: overlay,
        displaySeconds: _displaySeconds,
        locationLine: cityLine,
        addToAlbumId: _addToAlbumId,
        newAlbumName: _newAlbumName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final cs = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: bottomInset + 16,
        top: 8,
      ),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        minChildSize: 0.45,
        maxChildSize: 0.92,
        builder: (context, scroll) {
          return ListView(
            controller: scroll,
            children: [
              Text(
                '${s.albumSettingsTitle} · ${widget.photoPaths.length}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: Icon(Icons.folder_copy_outlined, color: cs.primary),
                title: Text(s.addToExistingAlbum),
                subtitle: Text(_addToAlbumName ?? '—'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _chooseExistingAlbum(s),
              ),
              ListTile(
                leading: Icon(Icons.create_new_folder_outlined, color: cs.primary),
                title: Text(s.createNewAlbum),
                subtitle: Text(_newAlbumName ?? '—'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _createAlbumDialog(s),
              ),
              const Divider(height: 28),
              Text(s.displaySettingsSection, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              ListTile(
                leading: Icon(Icons.timer_outlined, color: cs.primary),
                title: Text(s.displayTimeLabel),
                subtitle: Text('$_displaySeconds s'),
              ),
              Slider(
                min: 5,
                max: 120,
                divisions: 23,
                value: _displaySeconds.toDouble(),
                onChanged: (v) => setState(() => _displaySeconds = v.round()),
              ),
              SwitchListTile.adaptive(
                value: _customOn,
                onChanged: (v) => setState(() => _customOn = v),
                title: Text(s.addCustomTextLabel),
              ),
              if (_customOn)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: TextField(
                    controller: _customCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Enter your text…',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              SwitchListTile.adaptive(
                value: _cityWeatherOn,
                onChanged: (v) => setState(() => _cityWeatherOn = v),
                title: Text(s.showCityWeatherLabel),
                subtitle: Text(s.showCityWeatherDemo, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              ),
              SwitchListTile.adaptive(
                value: _holidayOn,
                onChanged: (v) => setState(() => _holidayOn = v),
                title: Text(s.holidayReminderLabel),
              ),
              const SizedBox(height: 12),
              Text(s.photosSecureFootnote, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => _submit(s),
                child: Text('${s.sendToFrameCta} (${widget.photoPaths.length})'),
              ),
            ],
          );
        },
      ),
    );
  }
}
