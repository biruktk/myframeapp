import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import '../services/image_processor_service.dart';

/// Filter preview grid with thumbnails
class FilterPreviewSelector extends StatefulWidget {
  const FilterPreviewSelector({
    super.key,
    required this.sourceImage,
    required this.currentFilter,
    required this.onFilterSelected,
    this.brightness = 1.0,
    this.contrast = 1.0,
    this.saturation = 1.0,
  });

  final img.Image sourceImage;
  final FrameImageFilter currentFilter;
  final Function(FrameImageFilter) onFilterSelected;
  final double brightness;
  final double contrast;
  final double saturation;

  @override
  State<FilterPreviewSelector> createState() => _FilterPreviewSelectorState();
}

class _FilterPreviewSelectorState extends State<FilterPreviewSelector> {
  final Map<FrameImageFilter, Uint8List?> _previewCache = {};
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    _generatePreviews();
  }

  Future<void> _generatePreviews() async {
    if (_generating) return;
    setState(() => _generating = true);

    try {
      // Generate thumbnail for faster preview
      final processor = ImageProcessorService();
      final thumbnail = processor.buildPreview(
        source: widget.sourceImage,
        maxSide: 200,
        brightness: widget.brightness,
        contrast: widget.contrast,
        saturation: widget.saturation,
      );

      // Generate previews for all filters in parallel
      final futures = FrameImageFilter.values.map((filter) async {
        final preview = await compute(_generateFilterPreview, {
          'image': thumbnail,
          'filter': filter,
        });
        if (mounted) {
          setState(() {
            _previewCache[filter] = preview;
          });
        }
      });

      await Future.wait(futures);
    } catch (e) {
      debugPrint('Filter preview generation error: $e');
    } finally {
      if (mounted) {
        setState(() => _generating = false);
      }
    }
  }

  static Future<Uint8List?> _generateFilterPreview(Map<String, dynamic> args) async {
    try {
      final processor = ImageProcessorService();
      final image = args['image'] as img.Image;
      final filter = args['filter'] as FrameImageFilter;

      final filtered = processor.buildPreview(
        source: image,
        maxSide: 200,
        filter: filter,
      );

      return processor.encodeJpg(filtered, quality: 85);
    } catch (e) {
      return null;
    }
  }

  String _filterName(FrameImageFilter filter) {
    switch (filter) {
      case FrameImageFilter.none:
        return 'Original';
      case FrameImageFilter.grayscale:
        return 'B&W';
      case FrameImageFilter.sepia:
        return 'Sepia';
      case FrameImageFilter.warm:
        return 'Warm';
      case FrameImageFilter.cool:
        return 'Cool';
      case FrameImageFilter.contrast:
        return 'Contrast';
      case FrameImageFilter.vivid:
        return 'Vivid';
      case FrameImageFilter.vintage:
        return 'Vintage';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      height: 140,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: FrameImageFilter.values.length,
        itemBuilder: (context, index) {
          final filter = FrameImageFilter.values[index];
          final preview = _previewCache[filter];
          final isSelected = widget.currentFilter == filter;

          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => widget.onFilterSelected(filter),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? colorScheme.primary
                            : colorScheme.outline,
                        width: isSelected ? 3 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: colorScheme.primary.withOpacity(0.3),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ]
                          : null,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: preview != null
                          ? Image.memory(
                              preview,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              color: colorScheme.surfaceVariant,
                              child: Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      colorScheme.primary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _filterName(filter),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Bottom sheet wrapper for filter selector
class FilterPreviewBottomSheet extends StatelessWidget {
  const FilterPreviewBottomSheet({
    super.key,
    required this.sourceImage,
    required this.currentFilter,
    required this.onFilterSelected,
    this.brightness = 1.0,
    this.contrast = 1.0,
    this.saturation = 1.0,
  });

  final img.Image sourceImage;
  final FrameImageFilter currentFilter;
  final Function(FrameImageFilter) onFilterSelected;
  final double brightness;
  final double contrast;
  final double saturation;

  static Future<FrameImageFilter?> show(
    BuildContext context, {
    required img.Image sourceImage,
    required FrameImageFilter currentFilter,
    double brightness = 1.0,
    double contrast = 1.0,
    double saturation = 1.0,
  }) {
    return showModalBottomSheet<FrameImageFilter>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => FilterPreviewBottomSheet(
        sourceImage: sourceImage,
        currentFilter: currentFilter,
        onFilterSelected: (filter) {
          Navigator.pop(context, filter);
        },
        brightness: brightness,
        contrast: contrast,
        saturation: saturation,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.onSurfaceVariant.withOpacity(0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Title
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Row(
              children: [
                Icon(
                  Icons.filter_vintage_rounded,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  'Choose Filter',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Filter previews
          FilterPreviewSelector(
            sourceImage: sourceImage,
            currentFilter: currentFilter,
            onFilterSelected: onFilterSelected,
            brightness: brightness,
            contrast: contrast,
            saturation: saturation,
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
