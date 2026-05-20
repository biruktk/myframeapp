import 'package:flutter/material.dart';

/// Red (default mockup) or green accent; combined with light/dark in [light] / [dark].
enum AppAccent {
  red,
  green,
}

/// Themes aligned with `ra/ui/mobile-app-dualmode.html` (red) plus green variant.
class AppTheme {
  AppTheme._();

  /// Brand red (website + app redesign).
  static const Color primaryRed = Color(0xFFDC2626);
  static const Color primaryRedDark = Color(0xFFB91C1C);
  static const Color primaryGreen = Color(0xFF16A34A);
  static const Color primaryGreenDark = Color(0xFF15803D);

  /// Legacy alias — prefer [seed] / theme [ColorScheme.primary].
  static const Color primary = primaryRed;
  static const Color accentRed = primaryRed;
  static const Color accentRedDark = primaryRedDark;
  static const Color successGreen = Color(0xFF2E7D32);
  static const Color sdOrange = Color(0xFFFF9800);

  static Color seed(AppAccent accent) =>
      accent == AppAccent.green ? primaryGreen : primaryRed;

  static Color seedDark(AppAccent accent) =>
      accent == AppAccent.green ? primaryGreenDark : primaryRedDark;

  static ThemeData light(AppAccent accent, {bool comfort = false}) {
    final primary = seed(accent);
    // Strong body text; secondary still passes WCAG-style contrast on off-white.
    const onSurface = Color(0xFF0A0A0A);
    const onSurfaceVariant = Color(0xFF374151);
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.light,
        primary: primary,
        onPrimary: Colors.white,
        surface: Colors.white,
        onSurface: onSurface,
        onSurfaceVariant: onSurfaceVariant,
        outline: Color(0xFFD1D5DB),
        outlineVariant: Color(0xFFE5E7EB),
      ),
      visualDensity: comfort ? VisualDensity.comfortable : VisualDensity.standard,
    );
    final navH = comfort ? 76.0 : 68.0;
    final navLabel = comfort ? 13.0 : 11.0;
    final iconSz = comfort ? 26.0 : 22.0;
    return base.copyWith(
      scaffoldBackgroundColor: const Color(0xFFF3F4F6),
      hintColor: onSurfaceVariant,
      // Slightly snappier than [InkRipple] for list tiles and quick taps.
      splashFactory: InkSplash.splashFactory,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: Size(comfort ? 52 : 48, comfort ? 52 : 48),
          padding: EdgeInsets.symmetric(horizontal: comfort ? 22 : 18, vertical: comfort ? 14 : 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: Size(comfort ? 52 : 48, comfort ? 52 : 48),
        ),
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: onSurface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        color: Colors.white,
      ),
      listTileTheme: ListTileThemeData(
        minVerticalPadding: comfort ? 12 : 8,
        iconColor: onSurfaceVariant,
        textColor: onSurface,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: navH,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        indicatorColor: primary,
        labelTextStyle: WidgetStateProperty.resolveWith((s) {
          final selected = s.contains(WidgetState.selected);
          return TextStyle(
            fontSize: navLabel,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? primary : onSurfaceVariant,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((s) {
          final selected = s.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? Colors.white : onSurfaceVariant,
            size: iconSz,
          );
        }),
      ),
    );
  }

  static ThemeData dark(AppAccent accent, {bool comfort = false}) {
    final primary = seed(accent);
    const surface = Color(0xFF1F2937);
    const scaffold = Color(0xFF111827);
    const onSurfaceD = Color(0xFFF3F4F6);
    const onVarD = Color(0xFF9CA3AF);
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.dark,
        primary: primary,
        onPrimary: Colors.white,
        surface: surface,
        onSurface: onSurfaceD,
        onSurfaceVariant: onVarD,
        outline: Color(0xFF4B5563),
        outlineVariant: Color(0xFF374151),
      ),
    );
    final navH = comfort ? 76.0 : 68.0;
    final navLabel = comfort ? 13.0 : 11.0;
    final iconSz = comfort ? 26.0 : 22.0;
    return base.copyWith(
      scaffoldBackgroundColor: scaffold,
      visualDensity: comfort ? VisualDensity.comfortable : VisualDensity.standard,
      hintColor: Colors.white70,
      splashFactory: InkSplash.splashFactory,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: Size(comfort ? 52 : 48, comfort ? 52 : 48),
        ),
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: surface,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade800),
        ),
        color: surface,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: navH,
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        indicatorColor: primary,
        labelTextStyle: WidgetStateProperty.resolveWith((s) {
          final selected = s.contains(WidgetState.selected);
          return TextStyle(
            fontSize: navLabel,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? primary : Colors.grey.shade400,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((s) {
          final selected = s.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? Colors.white : Colors.grey.shade400,
            size: iconSz,
          );
        }),
      ),
    );
  }
}
