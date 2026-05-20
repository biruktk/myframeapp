import 'image_processor_service.dart';
import 'slideshow_style.dart';
import 'transport_kind.dart';

/// Last-used edit & send options so leaving the editor (back) and opening a new
/// photo keeps color grade, filters, transport, slideshow, and overlay toggles.
class EditorSettingsSnapshot {
  const EditorSettingsSnapshot({
    required this.transport,
    required this.slideshow,
    required this.showDate,
    required this.showLocation,
    required this.showGreeting,
    required this.customText,
    required this.brightness,
    required this.contrast,
    required this.saturation,
    required this.filter,
  });

  final TransportKind transport;
  final SlideshowStyle slideshow;
  final bool showDate;
  final bool showLocation;
  final bool showGreeting;
  final String customText;
  final double brightness;
  final double contrast;
  final double saturation;
  final FrameImageFilter filter;
}

class EditorSettingsCache {
  EditorSettingsCache._();
  static final EditorSettingsCache instance = EditorSettingsCache._();

  EditorSettingsSnapshot? _last;

  /// Non-null after the user has closed [ImageEditorScreen] at least once.
  EditorSettingsSnapshot? get last => _last;

  void update(EditorSettingsSnapshot snapshot) {
    _last = snapshot;
  }
}
