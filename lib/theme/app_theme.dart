import 'package:flutter/material.dart';

/// Red (default mockup) or green accent; combined with light/dark in [light] / [dark].
enum AppAccent {
  red,
  green,
}

/// Auth‑focused styling: modern filled rounded inputs, primary button spec.
class AppAuthTheme {
  AppAuthTheme._();

  static const Color primaryRed = Color(0xFFE53935);
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
    final fill = isDark ? cs.surfaceContainerHighest : const Color(0xFFF5F5F7);
    final borderColor = cs.outlineVariant;
    final enabledBorderColor = isDark ? cs.outline : const Color(0xFFEEEEEE);
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

/// Themes: solid red accents on white / soft-grey surfaces — no pink seed tints.
class AppTheme {
  AppTheme._();

  /// Brand red (solid accent — never used as a washed container fill).
  static const Color primaryRed = Color(0xFFE53935);
  static const Color primaryRedDark = Color(0xFFC62828);
  static const Color primaryGreen = Color(0xFF16A34A);
  static const Color primaryGreenDark = Color(0xFF15803D);

  /// Neutral greys (cards, chips, placeholders, segmented tracks).
  static const Color neutralGrey50 = Color(0xFFF8F9FA);
  static const Color neutralGrey100 = Color(0xFFF5F5F7);
  static const Color neutralGrey150 = Color(0xFFF1F3F5);
  static const Color neutralGrey200 = Color(0xFFEEEEEE);
  static const Color charcoal = Color(0xFF1A1A1A);
  static const Color charcoalMuted = Color(0xFF5F6368);

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

  /// Light scheme with **explicit** neutrals so [ColorScheme.fromSeed] cannot
  /// inject pink `primaryContainer` / surface-container tints from a red seed.
  static ColorScheme _lightScheme(Color primary) {
    return ColorScheme(
      brightness: Brightness.light,
      primary: primary,
      onPrimary: Colors.white,
      primaryContainer: neutralGrey100,
      onPrimaryContainer: charcoal,
      secondary: charcoalMuted,
      onSecondary: Colors.white,
      secondaryContainer: neutralGrey150,
      onSecondaryContainer: charcoal,
      tertiary: primary,
      onTertiary: Colors.white,
      tertiaryContainer: neutralGrey100,
      onTertiaryContainer: charcoal,
      error: const Color(0xFFB3261E),
      onError: Colors.white,
      errorContainer: const Color(0xFFF5F5F7),
      onErrorContainer: charcoal,
      surface: Colors.white,
      onSurface: charcoal,
      onSurfaceVariant: charcoalMuted,
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: neutralGrey50,
      surfaceContainer: neutralGrey100,
      surfaceContainerHigh: neutralGrey150,
      surfaceContainerHighest: neutralGrey200,
      outline: const Color(0xFFD1D5DB),
      outlineVariant: neutralGrey200,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: charcoal,
      onInverseSurface: Colors.white,
      inversePrimary: primary,
      surfaceTint: Colors.transparent,
    );
  }

  static ColorScheme _darkScheme(Color primary) {
    // High-contrast dark surfaces: crisp white / light-grey text on deep navy.
    const surface = Color(0xFF121820);
    const onSurface = Color(0xFFFFFFFF);
    const onVar = Color(0xFFB0BEC5);
    return ColorScheme(
      brightness: Brightness.dark,
      primary: primary,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFF374151),
      onPrimaryContainer: onSurface,
      secondary: onVar,
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFF1E2836),
      onSecondaryContainer: onSurface,
      tertiary: primary,
      onTertiary: Colors.white,
      tertiaryContainer: const Color(0xFF374151),
      onTertiaryContainer: onSurface,
      error: const Color(0xFFF87171),
      onError: Colors.black,
      errorContainer: const Color(0xFF374151),
      onErrorContainer: onSurface,
      surface: surface,
      onSurface: onSurface,
      onSurfaceVariant: onVar,
      surfaceContainerLowest: const Color(0xFF0B1016),
      surfaceContainerLow: const Color(0xFF121820),
      surfaceContainer: const Color(0xFF1A2332),
      surfaceContainerHigh: const Color(0xFF243044),
      surfaceContainerHighest: const Color(0xFF2D3748),
      outline: const Color(0xFF4B5563),
      outlineVariant: const Color(0xFF374151),
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: onSurface,
      onInverseSurface: charcoal,
      inversePrimary: primary,
      surfaceTint: Colors.transparent,
    );
  }

  static InputDecorationTheme _inputDecoration({
    required ColorScheme cs,
    required bool dark,
  }) {
    final radius = BorderRadius.circular(12);
    final fill = dark ? cs.surfaceContainerHighest : neutralGrey50;
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
    final cs = _lightScheme(primary);
    final navH = comfort ? 76.0 : 68.0;
    final navLabel = comfort ? 13.0 : 11.0;
    final iconSz = comfort ? 26.0 : 22.0;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: cs,
      visualDensity: comfort ? VisualDensity.comfortable : VisualDensity.standard,
      scaffoldBackgroundColor: neutralGrey150,
      hintColor: charcoalMuted,
      splashFactory: InkSplash.splashFactory,
      applyElevationOverlayColor: false,
      inputDecorationTheme: _inputDecoration(cs: cs, dark: false),
      dialogTheme: const DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: Colors.white,
      ),
      popupMenuTheme: const PopupMenuThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 3,
        focusElevation: 4,
        hoverElevation: 4,
        highlightElevation: 4,
        extendedPadding: const EdgeInsets.symmetric(horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: neutralGrey100,
        selectedColor: primary,
        disabledColor: neutralGrey200,
        side: const BorderSide(color: neutralGrey200),
        labelStyle: const TextStyle(color: charcoal),
        secondaryLabelStyle: const TextStyle(color: Colors.white),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: primary.withValues(alpha: 0.45),
          disabledForegroundColor: Colors.white,
          minimumSize: Size(comfort ? 52 : 48, comfort ? 52 : 48),
          padding: EdgeInsets.symmetric(
            horizontal: comfort ? 22 : 18,
            vertical: comfort ? 14 : 12,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: charcoal,
          side: const BorderSide(color: neutralGrey200),
          minimumSize: Size(comfort ? 52 : 48, comfort ? 52 : 48),
        ),
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: charcoal,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: charcoal,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: neutralGrey200),
        ),
        color: Colors.white,
      ),
      listTileTheme: ListTileThemeData(
        minVerticalPadding: comfort ? 12 : 8,
        iconColor: charcoalMuted,
        textColor: charcoal,
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
            color: selected ? primary : charcoalMuted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((s) {
          final selected = s.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? Colors.white : charcoalMuted,
            size: iconSz,
          );
        }),
      ),
    );
  }

  static ThemeData dark(AppAccent accent, {bool comfort = false}) {
    final primary = seed(accent);
    const surface = Color(0xFF121820);
    const scaffold = Color(0xFF121820);
    const onSurfaceD = Color(0xFFFFFFFF);
    const onVarD = Color(0xFFB0BEC5);
    const bodyLight = Color(0xFFE0E0E0);
    final cs = _darkScheme(primary);
    final navH = comfort ? 76.0 : 68.0;
    final navLabel = comfort ? 13.0 : 11.0;
    final iconSz = comfort ? 26.0 : 22.0;
    final baseText = ThemeData(brightness: Brightness.dark).textTheme;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: cs,
      scaffoldBackgroundColor: scaffold,
      visualDensity: comfort ? VisualDensity.comfortable : VisualDensity.standard,
      hintColor: onVarD,
      splashFactory: InkSplash.splashFactory,
      applyElevationOverlayColor: false,
      // Enforce high-contrast typography so screens that omit explicit colors
      // still render readable white / light-grey text on dark backgrounds.
      textTheme: baseText.copyWith(
        displayLarge: baseText.displayLarge?.copyWith(color: onSurfaceD),
        displayMedium: baseText.displayMedium?.copyWith(color: onSurfaceD),
        displaySmall: baseText.displaySmall?.copyWith(color: onSurfaceD),
        headlineLarge: baseText.headlineLarge?.copyWith(color: onSurfaceD),
        headlineMedium: baseText.headlineMedium?.copyWith(color: onSurfaceD),
        headlineSmall: baseText.headlineSmall?.copyWith(color: onSurfaceD),
        titleLarge: baseText.titleLarge?.copyWith(
          color: onSurfaceD,
          fontWeight: FontWeight.bold,
        ),
        titleMedium: baseText.titleMedium?.copyWith(color: onSurfaceD),
        titleSmall: baseText.titleSmall?.copyWith(color: onSurfaceD),
        bodyLarge: baseText.bodyLarge?.copyWith(color: bodyLight),
        bodyMedium: baseText.bodyMedium?.copyWith(color: bodyLight),
        bodySmall: baseText.bodySmall?.copyWith(color: onVarD),
        labelLarge: baseText.labelLarge?.copyWith(color: onSurfaceD),
        labelMedium: baseText.labelMedium?.copyWith(color: onVarD),
        labelSmall: baseText.labelSmall?.copyWith(color: onVarD),
      ),
      primaryTextTheme: baseText.apply(
        bodyColor: onSurfaceD,
        displayColor: onSurfaceD,
      ),
      inputDecorationTheme: _inputDecoration(cs: cs, dark: true),
      dialogTheme: const DialogThemeData(
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
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: Size(comfort ? 52 : 48, comfort ? 52 : 48),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: onSurfaceD,
          side: BorderSide(color: cs.outline),
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
        iconTheme: IconThemeData(color: onSurfaceD),
        actionsIconTheme: IconThemeData(color: onSurfaceD),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: cs.outlineVariant),
        ),
        color: cs.surfaceContainer,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: onVarD,
        textColor: onSurfaceD,
        titleTextStyle: TextStyle(
          color: onSurfaceD,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
        subtitleTextStyle: TextStyle(color: onVarD, fontSize: 13),
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
            color: selected ? primary : onVarD,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((s) {
          final selected = s.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? Colors.white : onVarD,
            size: iconSz,
          );
        }),
      ),
    );
  }
}
