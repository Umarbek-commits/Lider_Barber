import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Overridden in main() with the persisted choice (defaults to dark).
final initialThemeModeProvider = Provider<ThemeMode>((_) => ThemeMode.dark);

class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ref.read(initialThemeModeProvider);

  Future<void> toggle() async {
    state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme', state == ThemeMode.dark ? 'dark' : 'light');
  }
}

final themeModeControllerProvider =
    NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);

Future<ThemeMode> loadSavedThemeMode() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('theme') == 'light' ? ThemeMode.light : ThemeMode.dark;
}
