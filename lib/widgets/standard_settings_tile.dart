import 'package:flutter/material.dart';

class StandardSettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isDestructive;

  const StandardSettingsTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isDestructive = false,
  });

  static const _primaryRed = Color(0xFFE53935);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 0,
        color: cs.surface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: cs.outlineVariant),
        ),
        child: ListTile(
          onTap: onTap,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _primaryRed.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: _primaryRed, size: 22),
          ),
          title: Text(
            title,
            style: tt.titleMedium?.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDestructive ? _primaryRed : cs.onSurface,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              subtitle,
              style: tt.bodyMedium?.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.normal,
                color: cs.onSurfaceVariant,
                height: 1.3,
              ),
            ),
          ),
          trailing: Icon(Icons.chevron_right,
              color: cs.onSurfaceVariant, size: 20),
        ),
      ),
    );
  }
}
