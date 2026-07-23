import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../app/theme_mode.dart';

/// Sun/moon button that toggles light ↔ dark, persisted.
class ThemeToggle extends ConsumerWidget {
  const ThemeToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeControllerProvider);
    final isDark = mode == ThemeMode.dark;
    return IconButton(
      tooltip: isDark ? 'Светлая тема' : 'Тёмная тема',
      onPressed: () => ref.read(themeModeControllerProvider.notifier).toggle(),
      icon: Icon(
        isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
        color: AppColors.gold,
        size: 22,
      ),
    );
  }
}
