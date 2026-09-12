import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../services/device_store.dart';

/// Horizontal, scroll-safe destination picker for one or many paired frames.
///
/// - 0/1 paired frame → compact single indicator (never an awkward carousel).
/// - 2+ frames → rounded chips with brand-red selected state.
/// - Works in single-select and multi-select modes without overflow.
class FrameTargetSelector extends StatelessWidget {
  const FrameTargetSelector({
    super.key,
    required this.frames,
    required this.selectedIds,
    required this.onToggle,
    this.multiSelect = true,
    this.title,
  });

  final List<PairedFrame> frames;
  final Set<String> selectedIds;
  final ValueChanged<String> onToggle;
  final bool multiSelect;

  /// Optional section label (e.g. "Send to:").
  final String? title;

  static const _red = Color(0xFFE53935);
  static const _redTint = Color(0xFFFFF1F0);

  String _label(PairedFrame f) {
    final n = (f.frameName ?? '').trim();
    if (n.isNotEmpty) return n;
    return f.listDisplayTitle(AppStrings.current);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (frames.isEmpty) return const SizedBox.shrink();

    // Single-frame account: compact indicator, no carousel.
    if (frames.length == 1) {
      final f = frames.first;
      final selected = selectedIds.isEmpty || selectedIds.contains(f.deviceId);
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            if (title != null) ...[
              Text(
                title!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: selected ? _redTint : cs.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected ? _red : Colors.grey.shade300,
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.photo_size_select_actual_outlined,
                    size: 15,
                    color: selected ? _red : cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      _label(f),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: selected ? _red : cs.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFF2E9E5B),
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              title!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        SizedBox(
          height: 46,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: frames.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final f = frames[i];
              final selected = selectedIds.contains(f.deviceId);
              return _chip(context, f, selected);
            },
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _chip(BuildContext context, PairedFrame f, bool selected) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => onToggle(f.deviceId),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _redTint : cs.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? _red : Colors.grey.shade300,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked,
              size: 16,
              color: selected ? _red : cs.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              _label(f),
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                color: selected ? _red : cs.onSurface,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: selected ? _red : Colors.grey.shade400,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
