class SendOverlayOptions {
  const SendOverlayOptions({
    this.showDate = false,
    this.showLocation = false,
    this.showGreeting = false,
    this.showWeather = false,
    this.customText = '',
    this.greetingCustom,
    this.centerText = '',
    this.centerTextColor = 0xFFFFFFFF,
    this.centerTextSize = 38,
    this.centerSticker = '',
    this.weatherText = '',
    this.stickerAlignX = 0.62,
    this.stickerAlignY = 0.40,
    this.stickerSize = 28,
  });

  final bool showDate;
  final bool showLocation;
  final bool showGreeting;
  final bool showWeather;
  final String customText;
  /// When [showGreeting] is true, drawn instead of the default greeting line.
  final String? greetingCustom;

  /// Editor "Add Text" — drawn in the bottom gray bar under weather/date.
  final String centerText;
  final int centerTextColor;
  final double centerTextSize;

  /// Sticker glyph drawn slightly right of center (adjustable).
  final String centerSticker;
  final double stickerAlignX;
  final double stickerAlignY;
  /// UI sticker size (default 28). Bake scales relative to image width.
  final double stickerSize;

  /// Real weather line (e.g. "☀ 24°C · Paris").
  final String weatherText;

  bool get hasAnyOverlay =>
      showDate ||
      showLocation ||
      showGreeting ||
      showWeather ||
      customText.trim().isNotEmpty ||
      centerText.trim().isNotEmpty ||
      centerSticker.trim().isNotEmpty ||
      weatherText.trim().isNotEmpty;
}
