import 'dart:io';

import 'package:flutter/material.dart';

import '../services/app_diag_log.dart';

/// Soft fallback panel used when a playlist/album preview fails to build.
class SafeRenderFallback extends StatelessWidget {
  const SafeRenderFallback({
    super.key,
    this.message,
    this.onRetry,
  });

  final String? message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface,
      child: InkWell(
        onTap: onRetry,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.broken_image_outlined, size: 40, color: cs.outline),
                const SizedBox(height: 12),
                Text(
                  message ??
                      'Unable to load playlist preview. Tap to refresh.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Wraps a preview subtree. Pair with a [ValueKey] on [child] so list length
/// changes rebuild cleanly instead of mutating stale PageView/GridView slots.
class SafeRenderBoundary extends StatelessWidget {
  const SafeRenderBoundary({
    super.key,
    required this.child,
    this.message,
    this.onRetry,
  });

  final Widget child;
  final String? message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    // Child build failures are handled by AppReleaseGuard's ErrorWidget.builder.
    // This wrapper ensures the area always has a non-black Material backdrop.
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: child,
    );
  }
}

/// Safe local file image — never throws on empty/missing paths.
class SafeFileImage extends StatelessWidget {
  const SafeFileImage({
    super.key,
    required this.path,
    this.fit = BoxFit.cover,
    this.cacheWidth,
    this.filterQuality = FilterQuality.low,
  });

  final String path;
  final BoxFit fit;
  final int? cacheWidth;
  final FilterQuality filterQuality;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final trimmed = path.trim();
    Widget broken() => ColoredBox(
          color: cs.surfaceContainerHighest,
          child: Icon(Icons.broken_image_outlined, color: cs.outline),
        );

    if (trimmed.isEmpty) return broken();

    try {
      final file = File(trimmed);
      if (!file.existsSync()) return broken();
      final ImageProvider provider = cacheWidth != null
          ? ResizeImage(FileImage(file), width: cacheWidth)
          : FileImage(file);
      return Image(
        image: provider,
        fit: fit,
        gaplessPlayback: true,
        filterQuality: filterQuality,
        errorBuilder: (_, __, ___) => broken(),
        frameBuilder: (context, child, frame, sync) {
          if (sync || frame != null) return child;
          return ColoredBox(
            color: cs.surfaceContainerHighest,
            child: Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: cs.primary,
                ),
              ),
            ),
          );
        },
      );
    } catch (e, st) {
      AppDiagLog.verbose('[SafeFileImage] $trimmed: $e\n$st');
      return broken();
    }
  }
}

/// Clamps a page/carousel index after the underlying list shrinks or grows.
int clampImageIndex(int index, int length) {
  if (length <= 0) return 0;
  if (index < 0) return 0;
  if (index >= length) return length - 1;
  return index;
}
