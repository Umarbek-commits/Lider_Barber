import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/constants.dart';
import '../../l10n/l10n.dart';

/// Public-facing scaffold: top navigation (with language toggle) + centered,
/// max-width content column.
class PageShell extends StatelessWidget {
  const PageShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 760;
    return Scaffold(
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TopNav(isMobile: isMobile),
                  const SizedBox(height: 24),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopNav extends ConsumerWidget {
  const _TopNav({required this.isMobile});
  final bool isMobile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final logo = GestureDetector(
      onTap: () => context.go('/'),
      child: const Text(BusinessInfo.name,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.gold)),
    );
    final links = [
      (label: t.navServices, path: '/services'),
      (label: t.navBook, path: '/book'),
      (label: t.navCabinet, path: '/account'),
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        logo,
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isMobile)
              PopupMenuButton<String>(
                icon: const Icon(Icons.menu_rounded),
                onSelected: (path) => context.go(path),
                itemBuilder: (_) => links
                    .map((l) => PopupMenuItem(value: l.path, child: Text(l.label)))
                    .toList(),
              )
            else
              Row(
                children: links
                    .map((l) => TextButton(
                          onPressed: () => context.go(l.path),
                          child: Text(l.label, style: const TextStyle(color: Colors.white70)),
                        ))
                    .toList(),
              ),
            const SizedBox(width: 4),
            const _LanguageToggle(),
          ],
        ),
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
