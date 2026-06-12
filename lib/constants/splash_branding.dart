import 'package:flutter/services.dart';

/// Splash logo bytes loaded before [runApp] so the icon paints on frame 1.
abstract final class SplashBranding {
  static Uint8List? iconPngBytes;

  static const iconAssetPath = 'assets/branding/myframe_splash_logo.png';

  static Future<void> preload() async {
    try {
      final data = await rootBundle.load(iconAssetPath);
      iconPngBytes = data.buffer.asUint8List();
    } catch (_) {
      iconPngBytes = null;
    }
  }
}
