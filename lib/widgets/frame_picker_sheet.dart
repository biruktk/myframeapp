import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../services/device_store.dart';

/// Bottom sheet: pick which paired frame receives the photo.
Future<PairedFrame?> showFramePickerSheet(
  BuildContext context, {
  required List<PairedFrame> frames,
}) {
  final s = AppStrings.of(context);
  return showModalBottomSheet<PairedFrame>(
    context: context,
    showDragHandle: true,
    isScrollControlled: frames.length > 6,
    builder: (ctx) {
      final cs = Theme.of(ctx).colorScheme;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                s.sendToFrame,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              const SizedBox(height: 4),
              Text(
                s.chooseFrameToSendHint,
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13, height: 1.35),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: frames.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final f = frames[i];
                    final title = f.frameName?.trim().isNotEmpty == true
                        ? f.frameName!.trim()
                        : f.listDisplayTitle(s);
                    return Material(
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(12),
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        leading: Icon(Icons.devices_outlined, color: cs.primary),
                        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          f.deviceId,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                        ),
                        trailing: Icon(Icons.chevron_right, color: cs.outline),
                        onTap: () => Navigator.pop(ctx, f),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
