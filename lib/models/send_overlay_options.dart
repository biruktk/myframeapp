class SendOverlayOptions {
  const SendOverlayOptions({
    this.showDate = false,
    this.showLocation = false,
    this.showGreeting = false,
    this.customText = '',
    this.greetingCustom,
  });

  final bool showDate;
  final bool showLocation;
  final bool showGreeting;
  final String customText;
  /// When [showGreeting] is true, drawn instead of the default greeting line.
  final String? greetingCustom;

  bool get hasAnyOverlay =>
      showDate || showLocation || showGreeting || customText.trim().isNotEmpty;
}
