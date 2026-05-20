import 'dart:io';

import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';

/// Multi-select grid of file paths (Personal library) for adding to an album.
class PickPersonalPhotosDialog extends StatefulWidget {
  const PickPersonalPhotosDialog({super.key, required this.available, required this.strings});

  final List<String> available;
  final AppStrings strings;

  @override
  State<PickPersonalPhotosDialog> createState() => _PickPersonalPhotosDialogState();
}

class _PickPersonalPhotosDialogState extends State<PickPersonalPhotosDialog> {
  final Set<String> _sel = {};

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(s.albumSelectPhotosTitle),
      content: SizedBox(
        width: double.maxFinite,
        height: 380,
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 6,
            mainAxisSpacing: 6,
          ),
          itemCount: widget.available.length,
          itemBuilder: (context, i) {
            final path = widget.available[i];
            final on = _sel.contains(path);
            return GestureDetector(
              onTap: () => setState(() {
                if (on) {
                  _sel.remove(path);
                } else {
                  _sel.add(path);
                }
              }),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(File(path), fit: BoxFit.cover),
                  ),
                  if (on)
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: cs.primary, width: 3),
                        color: cs.primary.withValues(alpha: 0.2),
                      ),
                    ),
                  if (on)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Icon(Icons.check_circle, color: cs.primary, size: 22),
                    ),
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(s.cancel)),
        FilledButton(
          onPressed: _sel.isEmpty ? null : () => Navigator.pop(context, _sel.toList()),
          child: Text(s.albumAddSelected),
        ),
      ],
    );
  }
}
