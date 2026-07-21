import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/constants.dart';
import '../../l10n/l10n.dart';

/// Public-facing scaffold: minimal top bar (logo + language toggle) and a
/// bottom navigation bar (Home / Services / Booking / Cabinet).
class PageShell extends ConsumerWidget {
  const PageShell({super.key, required this.child});

  final Widget child;

  static const _tabs = ['/', '/services', '/book', '/account'];

  int _selectedIndex(String path) {
    if (path.startsWith('/services')) return 1;
    if (path.startsWith('/book')) return 2;
    if (path.startsWith('/account')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMobile = MediaQuery.of(context).size.width < 760;
    final t = ref.watch(tProvider);
    final path = GoRouterState.of(context).uri.path;
    final index = _selectedIndex(path);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Padding(
                padding:
                    EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _TopBar(),
                    const SizedBox(height: 20),
                    child,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => context.go(_tabs[i]),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: t.navHome,
          ),
          NavigationDestination(
            icon: const Icon(Icons.content_cut_outlined),
            selectedIcon: const Icon(Icons.content_cut),
            label: t.navServices,
          ),
          NavigationDestination(
            icon: const Icon(Icons.calendar_today_outlined),
            selectedIcon: const Icon(Icons.calendar_today),
            label: t.navBook,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: t.navCabinet,
          ),
        ],
      ),
    );
  }
}

/// Top bar: brand on the left, language toggle on the right.
class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: () => context.go('/'),
          child: const Text(BusinessInfo.name,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.gold)),
        ),
        const _LanguageToggle(),
      ],
    );
  }
}

class _LanguageToggle extends ConsumerWidget {
  const _LanguageToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeControllerProvider);
    return TextButton(
      onPressed: () => ref.read(localeControllerProvider.notifier).toggle(),
      style: TextButton.styleFrom(
        minimumSize: const Size(44, 40),
        padding: const EdgeInsets.symmetric(horizontal: 10),
      ),
      child: Text(
        locale == AppLocale.ru ? 'КЫРГ' : 'РУС',
        style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700, fontSize: 13),
      ),
    );
  }
}
