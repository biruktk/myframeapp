import 'dart:io';

import 'package:flutter/material.dart';

import '../services/app_diag_log.dart';
import '../services/gallery_image_normalizer.dart';

/// Soft fallback panel used when a playlist/album preview fails to build.
class SafeRenderFallback extends StatelessWidget {
  const SafeRenderFallback({super.key, this.message, this.onRetry});

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
                  message ?? 'Unable to load playlist preview. Tap to refresh.',
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
    this.brokenBuilder,
  });

  final String path;
  final BoxFit fit;
  final int? cacheWidth;
  final FilterQuality filterQuality;

  /// Replaces the default broken-image placeholder when rendering fails.
  /// The [VoidCallback] can be used to trigger a retry / repair.
  final Widget Function(VoidCallback retry)? brokenBuilder;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final trimmed = path.trim();
    Widget broken() => ColoredBox(
      color: cs.surfaceContainerHighest,
      child: Icon(Icons.broken_image_outlined, color: cs.outline),
    );

    if (trimmed.isEmpty) {
      return brokenBuilder != null ? brokenBuilder!(() {}) : broken();
    }

    try {
      final file = File(trimmed);
      if (!file.existsSync()) {
        return brokenBuilder != null ? brokenBuilder!(() {}) : broken();
      }
      final ImageProvider provider = cacheWidth != null
          ? ResizeImage(FileImage(file), width: cacheWidth)
          : FileImage(file);
      return Image(
        image: provider,
        fit: fit,
        gaplessPlayback: true,
        filterQuality: filterQuality,
        errorBuilder: (_, __, ___) =>
            brokenBuilder != null ? brokenBuilder!(() {}) : broken(),
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
      return brokenBuilder != null ? brokenBuilder!(() {}) : broken();
    }
  }
}

/// Local file image that self-heals: when the frame fails to render (HEIC,
/// 16-bit PNG, Display P3, …) it offers a one-tap re-encode into a plain sRGB
/// JPEG and swaps the path. Reports the repaired path through [onRepaired] so
/// callers can keep their own file list in sync.
class RepairableFileImage extends StatefulWidget {
  const RepairableFileImage({
    super.key,
    required this.path,
    this.fit = BoxFit.cover,
    this.cacheWidth,
    this.filterQuality = FilterQuality.low,
    this.onRepaired,
  });

  final String path;
  final BoxFit fit;
  final int? cacheWidth;
  final FilterQuality filterQuality;
  final ValueChanged<String>? onRepaired;

  @override
  State<RepairableFileImage> createState() => _RepairableFileImageState();
}

class _RepairableFileImageState extends State<RepairableFileImage> {
  late String _path = widget.path;
  bool _repairing = false;

  @override
  void didUpdateWidget(covariant RepairableFileImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _path = widget.path;
      _repairing = false;
    }
  }

  Future<void> _repair() async {
    if (_repairing) return;
    setState(() => _repairing = true);
    final repaired = await GalleryImageNormalizer.repairPathForPreview(_path);
    if (!mounted) return;
    setState(() => _repairing = false);
    if (repaired != null && repaired != _path) {
      setState(() => _path = repaired);
      widget.onRepaired?.call(repaired);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeFileImage(
      path: _path,
      fit: widget.fit,
      cacheWidth: widget.cacheWidth,
      filterQuality: widget.filterQuality,
      brokenBuilder: (_) => ColoredBox(
        color: cs.surfaceContainerHighest,
        child: InkWell(
          onTap: _repairing ? null : _repair,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _repairing
                        ? Icons.hourglass_top_rounded
                        : Icons.broken_image_outlined,
                    size: 40,
                    color: cs.outline,
                  ),
                  const SizedBox(height: 10),
                  if (_repairing)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Text(
                      'Could not render this photo. Tap to re-encode.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Clamps a page/carousel index after the underlying list shrinks or grows.
int clampImageIndex(int index, int length) {
  if (length <= 0) return 0;
  if (index < 0) return 0;
  if (index >= length) return length - 1;
  return index;
}
