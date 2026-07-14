import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/send_overlay_options.dart';
import '../services/send_albums_store.dart';
import 'text_input_bottom_sheet.dart';

/// Result of the Send flow bottom sheet (album only).
/// Date / weather / text / stickers are chosen on the editor preview.
class SendAlbumSheetResult {
  const SendAlbumSheetResult({
    required this.overlay,
    this.displaySeconds = 10,
    this.locationLine,
    this.addToAlbumId,
    this.newAlbumName,
  });

  final SendOverlayOptions overlay;
  /// Kept for API compatibility; UI no longer exposes display time.
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
  String? _addToAlbumId;
  String? _addToAlbumName;
  String? _newAlbumName;

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
    final name = await TextInputBottomSheet.show(
      context,
      title: s.createNewAlbum,
      label: s.newAlbumNameHint,
      confirmLabel: s.nextLabel,
    );
    if (name == null || name.isEmpty || !mounted) return;
    setState(() {
      _newAlbumName = name;
      _addToAlbumId = null;
      _addToAlbumName = null;
    });
  }

  void _submit() {
    Navigator.pop(
      context,
      SendAlbumSheetResult(
        overlay: const SendOverlayOptions(),
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
        initialChildSize: 0.42,
        minChildSize: 0.30,
        maxChildSize: 0.75,
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
              const SizedBox(height: 12),
              Text(s.photosSecureFootnote, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _submit,
                child: Text('${s.sendToFrameCta} (${widget.photoPaths.length})'),
              ),
            ],
          );
        },
      ),
    );
  }
}
