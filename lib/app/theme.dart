import 'package:flutter/material.dart';

/// Lider Barber brand palette — modern, minimalist, black + gold.
class AppColors {
  const AppColors._();

  static const Color gold = Color(0xFFD4A24C);
  static const Color background = Color(0xFF060606);
  static const Color surface = Color(0xFF121212);
  static const Color surfaceRaised = Color(0xFF1D1D1D);
  static const Color headerTop = Color(0xFF0F0F0F);
  static const Color headerBottom = Color(0xFF1A1A1A);
}

ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.gold,
      brightness: Brightness.dark,
    ),
  );

  return base.copyWith(
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.gold,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    ),
    // One consistent bottom bar for both the client and the admin panel.
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: const Color(0xFF0E0E0E),
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.gold.withValues(alpha: 0.18),
      height: 64,
      elevation: 0,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 24,
          color: states.contains(WidgetState.selected) ? AppColors.gold : Colors.white54,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: states.contains(WidgetState.selected) ? AppColors.gold : Colors.white54,
        ),
      ),
    ),
  );
}
