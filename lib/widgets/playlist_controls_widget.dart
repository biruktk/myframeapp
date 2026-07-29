import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/playback_config.dart';

class PlaylistControlsWidget extends StatelessWidget {
  final int selectedIntervalSeconds;
  final ValueChanged<int> onIntervalChanged;
  final int selectedStrategy;
  final ValueChanged<int> onStrategyChanged;
  final int selectedDurationHours;
  final ValueChanged<int> onDurationChanged;

  const PlaylistControlsWidget({
    super.key,
    required this.selectedIntervalSeconds,
    required this.onIntervalChanged,
    required this.selectedStrategy,
    required this.onStrategyChanged,
    required this.selectedDurationHours,
    required this.onDurationChanged,
  });

  static const List<Map<String, dynamic>> intervalPills = [
    {'seconds': 60, 'label': '1m'},
    {'seconds': 120, 'label': '2m'},
    {'seconds': 300, 'label': '5m'},
    {'seconds': 600, 'label': '10m'},
    {'seconds': 1800, 'label': '30m'},
    {'seconds': 3600, 'label': '1h'},
  ];

  Widget _chip({
    required BuildContext context,
    required String label,
    required bool selected,
    required VoidCallback onSelected,
  }) {
    final cs = Theme.of(context).colorScheme;
    return ChoiceChip(
      label: Text(
        selected ? '✓ $label' : label,
        style: TextStyle(
          color: selected ? cs.onPrimary : cs.onSurface,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
      selected: selected,
      selectedColor: cs.primary,
      backgroundColor: cs.surface,
      visualDensity: VisualDensity.compact,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: selected ? cs.primary : cs.outlineVariant,
        ),
      ),
      onSelected: (_) => onSelected(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final cs = Theme.of(context).colorScheme;
    final labelStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.bold,
      color: cs.onSurface,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s.intervalLabel, style: labelStyle),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: intervalPills.map((item) {
            final seconds = item['seconds'] as int;
            final label = item['label'] as String;
            return _chip(
              context: context,
              label: label,
              selected: selectedIntervalSeconds == seconds,
              onSelected: () => onIntervalChanged(seconds),
            );
          }).toList(),
        ),
        const SizedBox(height: 10),
        Text(s.playbackMode, style: labelStyle),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _chip(
                context: context,
                label: s.sequential,
                selected: selectedStrategy == 1,
                onSelected: () => onStrategyChanged(1),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _chip(
                context: context,
                label: s.randomShuffle,
                selected: selectedStrategy == 2,
                onSelected: () => onStrategyChanged(2),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(s.durationLabel, style: labelStyle),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: PlaybackConfig.kDurationOptions.map((hours) {
            final label = hours == 0 ? s.unlimited : '${hours}h';
            return _chip(
              context: context,
              label: label,
              selected: selectedDurationHours == hours,
              onSelected: () => onDurationChanged(hours),
            );
          }).toList(),
        ),
      ],
    );
  }
}
