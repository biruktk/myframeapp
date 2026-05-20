import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../widgets/shell_navigation.dart';

/// Server-style playlist (swipe ordering on the glass) is **not** implemented yet — local album builder was removed to avoid a broken experience.
class PlaylistScreen extends StatelessWidget {
  const PlaylistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: Text(s.navPlaylist)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Icon(Icons.construction_outlined, size: 56, color: cs.primary),
          const SizedBox(height: 16),
          Text(
            s.playlistComingSoonTitle,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Text(s.playlistComingSoonBody, style: TextStyle(color: cs.onSurfaceVariant, height: 1.45)),
          const SizedBox(height: 20),
          Text(
            s.slideshowVsPlaylistTitle,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(s.slideshowVsPlaylistExplain, style: TextStyle(color: cs.onSurfaceVariant, height: 1.45)),
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: () => ShellNavigation.goToTab(2),
            icon: const Icon(Icons.view_carousel_outlined),
            label: Text(s.slideshowBatchTitle),
          ),
        ],
      ),
    );
  }
}
