import 'package:flutter/material.dart';

/// Lider Barber brand accent — gold works on both dark and light backgrounds.
class AppColors {
  const AppColors._();
  static const Color gold = Color(0xFFD4A24C);
}

/// Theme-aware semantic colors. Use `context.surface`, `context.muted`, … in
/// widgets so they adapt to the light/dark theme automatically.
extension AppPalette on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  /// Card / raised container background.
  Color get surface => isDark ? const Color(0xFF141414) : Colors.white;

  /// Slightly different container (unselected chips, avatars, insets).
  Color get surfaceAlt =>
      isDark ? const Color(0xFF1C1C1C) : const Color(0xFFECECEF);

  /// Hairline borders / dividers.
  Color get border => isDark
      ? Colors.white.withValues(alpha: 0.10)
      : Colors.black.withValues(alpha: 0.10);

  /// Primary text.
  Color get strong => isDark ? Colors.white : const Color(0xFF16171B);

  /// Secondary text.
  Color get muted =>
      isDark ? Colors.white70 : Colors.black.withValues(alpha: 0.62);

  /// Tertiary text.
  Color get faint =>
      isDark ? Colors.white54 : Colors.black.withValues(alpha: 0.48);

  /// Quaternary / hint text.
  Color get fainter =>
      isDark ? Colors.white38 : Colors.black.withValues(alpha: 0.36);
}

ThemeData buildDarkTheme() => _theme(Brightness.dark);
ThemeData buildLightTheme() => _theme(Brightness.light);

ThemeData _theme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor:
        isDark ? const Color(0xFF080808) : const Color(0xFFF6F6F8),
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.gold,
      brightness: brightness,
    ),
  );

  final navBg = isDark ? const Color(0xFF0E0E0E) : Colors.white;
  final navUnselected = isDark ? Colors.white54 : Colors.black54;

  return base.copyWith(
    appBarTheme: AppBarTheme(
      backgroundColor: navBg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.gold,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: navBg,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.gold.withValues(alpha: 0.18),
      height: 64,
      elevation: 0,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 24,
          color: states.contains(WidgetState.selected) ? AppColors.gold : navUnselected,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: states.contains(WidgetState.selected) ? AppColors.gold : navUnselected,
        ),
      ),
    ),
  );
}
