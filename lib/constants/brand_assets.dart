/// Central branding paths (Flutter [Image.asset], tests, docs).
class BrandAssets {
  BrandAssets._();

  /// Full lockup (icon + wordmark) for splash / marketing.
  static const String logoPathPng = 'assets/branding/myframe_logo.jpg';

  /// Same lockup as splash (icon + “MyFrame” text).
  static const String splashLogoPath = 'assets/branding/myframe_splash_logo.jpg';

  /// Red square app symbol only (no “MyFrame” text in the image).
  static const String appIconPath = 'assets/branding/myframe_app_icon.png';

  /// PNG app symbol for in-app branding (white canvas; clip to squircle on white pages).
  static const String splashIconPath = 'assets/branding/myframe_splash_logo.png';
}
