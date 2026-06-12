import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/app_diag_log.dart';
import '../settings/app_settings.dart';

/// Small floating **slog** button (right edge, vertically centered) when debug mode is on.
class DebugSlogOverlay extends StatelessWidget {
  const DebugSlogOverlay({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final debugOn = AppSettingsScope.of(context).debugModeEnabled;
    if (!debugOn) return child;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          right: 6,
          top: 0,
          bottom: 0,
          child: Center(
            child: _SlogFab(onTap: () => _openSlogSheet(context)),
          ),
        ),
      ],
    );
  }

  static Future<void> _openSlogSheet(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => const _SlogSheet(),
    );
  }
}

class _SlogFab extends StatelessWidget {
  const _SlogFab({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      elevation: 4,
      shadowColor: Colors.black26,
      color: cs.surfaceContainerHighest.withValues(alpha: 0.95),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Text(
            'slog',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
              color: cs.primary,
            ),
          ),
        ),
      ),
    );
  }
}

class _SlogSheet extends StatefulWidget {
  const _SlogSheet();

  @override
  State<_SlogSheet> createState() => _SlogSheetState();
}

class _SlogSheetState extends State<_SlogSheet> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  Future<void> _copyAll() async {
    final text = AppDiagLog.lines.join('\n');
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('Log copied'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'slog',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: AppDiagLog.lines.isEmpty ? null : _copyAll,
                icon: const Icon(Icons.copy_outlined, size: 18),
                label: const Text('Copy'),
              ),
              TextButton.icon(
                onPressed: AppDiagLog.lines.isEmpty
                    ? null
                    : () {
                        AppDiagLog.clear();
                        setState(() {});
                      },
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Clear'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.55,
            ),
            child: ValueListenableBuilder<int>(
              valueListenable: AppDiagLog.revision,
              builder: (context, _, __) {
                _scrollToEnd();
                final lines = AppDiagLog.lines;
                if (lines.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No log lines yet.',
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    ),
                  );
                }
                return DecoratedBox(
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  child: Scrollbar(
                    controller: _scroll,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _scroll,
                      padding: const EdgeInsets.all(12),
                      child: SelectableText(
                        lines.join('\n'),
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11.5,
                          height: 1.45,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
