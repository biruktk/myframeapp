import 'package:flutter/material.dart';

/// Red (default mockup) or green accent; combined with light/dark in [light] / [dark].
enum AppAccent {
  red,
  green,
}

/// Auth‑focused styling: modern filled rounded inputs, primary button spec.
class AppAuthTheme {
  AppAuthTheme._();

  static const Color primaryRed = Color(0xFFDC2626);
  static const Color bgLight = Color(0xFFF8F9FA);

  static InputDecoration inputStyle({
    required BuildContext context,
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final fill = isDark ? cs.surfaceContainerHighest : Colors.grey.shade50;
    final borderColor = cs.outlineVariant;
    final enabledBorderColor = isDark ? cs.outline : Colors.grey.shade200;
    final labelColor = cs.onSurfaceVariant;
    final iconColor = cs.onSurfaceVariant;

    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: labelColor, fontSize: 14),
      prefixIcon: Icon(icon, color: iconColor, size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: fill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: enabledBorderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.error, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.error, width: 1.5),
      ),
    );
  }
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

  static InputDecorationTheme _inputDecoration({
    required ColorScheme cs,
    required bool dark,
  }) {
    final radius = BorderRadius.circular(12);
    final fill = dark ? cs.surfaceContainerHighest : const Color(0xFFF9FAFB);
    return InputDecorationTheme(
      filled: true,
      fillColor: fill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      hintStyle: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
      labelStyle: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
      prefixIconColor: cs.onSurfaceVariant,
      suffixIconColor: cs.onSurfaceVariant,
      border: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: cs.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: cs.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: cs.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: cs.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: cs.error, width: 1.5),
      ),
    );
  }

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
        outline: const Color(0xFFD1D5DB),
        outlineVariant: const Color(0xFFE5E7EB),
      ),
      visualDensity: comfort ? VisualDensity.comfortable : VisualDensity.standard,
    );
    final cs = base.colorScheme;
    final navH = comfort ? 76.0 : 68.0;
    final navLabel = comfort ? 13.0 : 11.0;
    final iconSz = comfort ? 26.0 : 22.0;
    return base.copyWith(
      scaffoldBackgroundColor: const Color(0xFFF3F4F6),
      hintColor: onSurfaceVariant,
      // Slightly snappier than [InkRipple] for list tiles and quick taps.
      splashFactory: InkSplash.splashFactory,
      inputDecorationTheme: _inputDecoration(cs: cs, dark: false),
      dialogTheme: DialogThemeData(
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: cs.surface,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: cs.surface,
        surfaceTintColor: Colors.transparent,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: cs.surface,
        selectedColor: primary,
        disabledColor: cs.surfaceContainerHighest,
        side: BorderSide(color: cs.outlineVariant),
        labelStyle: TextStyle(color: cs.onSurface),
        secondaryLabelStyle: const TextStyle(color: Colors.white),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
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
        outline: const Color(0xFF4B5563),
        outlineVariant: const Color(0xFF374151),
        surfaceContainerHighest: const Color(0xFF374151),
        surfaceContainerHigh: const Color(0xFF2D3748),
        surfaceContainerLow: const Color(0xFF1A2332),
      ),
    );
    final cs = base.colorScheme;
    final navH = comfort ? 76.0 : 68.0;
    final navLabel = comfort ? 13.0 : 11.0;
    final iconSz = comfort ? 26.0 : 22.0;
    return base.copyWith(
      scaffoldBackgroundColor: scaffold,
      visualDensity: comfort ? VisualDensity.comfortable : VisualDensity.standard,
      hintColor: Colors.white70,
      splashFactory: InkSplash.splashFactory,
      inputDecorationTheme: _inputDecoration(cs: cs, dark: true),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: surface,
      ),
      popupMenuTheme: const PopupMenuThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: cs.surfaceContainerHighest,
        selectedColor: primary,
        disabledColor: cs.surfaceContainerLow,
        side: BorderSide(color: cs.outline),
        labelStyle: TextStyle(color: cs.onSurface),
        secondaryLabelStyle: const TextStyle(color: Colors.white),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
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
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: onSurfaceD,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade800),
        ),
        color: surface,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: onVarD,
        textColor: onSurfaceD,
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
