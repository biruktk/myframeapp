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

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.intervalLabel,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: intervalPills.map((item) {
            final seconds = item['seconds'] as int;
            final label = item['label'] as String;
            final isSelected = selectedIntervalSeconds == seconds;
            return ChoiceChip(
              label: Text(
                isSelected ? '✓ $label' : label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              selected: isSelected,
              selectedColor: const Color(0xFFE53935),
              backgroundColor: Colors.white,
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: isSelected ? const Color(0xFFE53935) : const Color(0xFFE0E0E0),
                ),
              ),
              onSelected: (_) => onIntervalChanged(seconds),
            );
          }).toList(),
        ),
        const SizedBox(height: 10),
        Text(
          s.playbackMode,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: ChoiceChip(
                label: Text(
                  selectedStrategy == 1 ? '✓ ${s.sequential}' : s.sequential,
                  style: TextStyle(
                    color: selectedStrategy == 1 ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                selected: selectedStrategy == 1,
                selectedColor: const Color(0xFFE53935),
                backgroundColor: Colors.white,
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: selectedStrategy == 1 ? const Color(0xFFE53935) : const Color(0xFFE0E0E0),
                  ),
                ),
                onSelected: (_) => onStrategyChanged(1),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ChoiceChip(
                label: Text(
                  selectedStrategy == 2 ? '✓ ${s.randomShuffle}' : s.randomShuffle,
                  style: TextStyle(
                    color: selectedStrategy == 2 ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                selected: selectedStrategy == 2,
                selectedColor: const Color(0xFFE53935),
                backgroundColor: Colors.white,
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: selectedStrategy == 2 ? const Color(0xFFE53935) : const Color(0xFFE0E0E0),
                  ),
                ),
                onSelected: (_) => onStrategyChanged(2),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          s.durationLabel,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: PlaybackConfig.kDurationOptions.map((hours) {
            final label = hours == 0 ? s.unlimited : '${hours}h';
            final isSelected = selectedDurationHours == hours;
            return ChoiceChip(
              label: Text(
                isSelected ? '✓ $label' : label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              selected: isSelected,
              selectedColor: const Color(0xFFE53935),
              backgroundColor: Colors.white,
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: isSelected ? const Color(0xFFE53935) : const Color(0xFFE0E0E0),
                ),
              ),
              onSelected: (_) => onDurationChanged(hours),
            );
          }).toList(),
        ),
      ],
    );
  }
}
