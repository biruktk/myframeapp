import 'package:flutter/material.dart';

class CustomSegmentedToggle extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabChanged;
  final int leftCount;
  final int rightCount;
  final String leftLabel;
  final String rightLabel;

  const CustomSegmentedToggle({
    super.key,
    required this.selectedIndex,
    required this.onTabChanged,
    required this.leftCount,
    required this.rightCount,
    required this.leftLabel,
    required this.rightLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Expanded(child: _tabItem(0, '$leftLabel · $leftCount')),
          Expanded(child: _tabItem(1, '$rightLabel · $rightCount')),
        ],
      ),
    );
  }

  Widget _tabItem(int index, String title) {
    final isSelected = selectedIndex == index;
    return GestureDetector(
      onTap: () => onTabChanged(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          boxShadow: isSelected
              ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 2))]
              : [],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              const Icon(Icons.check, size: 16, color: Color(0xFFE53935)),
              const SizedBox(width: 4),
            ],
            Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? const Color(0xFFE53935) : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
