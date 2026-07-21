import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/constants.dart';

/// Public-facing scaffold: top navigation + centered, max-width content column.
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

class _TopNav extends StatelessWidget {
  const _TopNav({required this.isMobile});
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final logo = GestureDetector(
      onTap: () => context.go('/'),
      child: const Text(BusinessInfo.name,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.gold)),
    );
    final links = [
      _NavLink('Услуги', '/services'),
      _NavLink('Запись', '/book'),
      _NavLink('Кабинет', '/login'),
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        logo,
        if (isMobile)
          PopupMenuButton<String>(
            icon: const Icon(Icons.menu_rounded),
            onSelected: (path) => context.go(path),
            itemBuilder: (_) =>
                links.map((l) => PopupMenuItem(value: l.path, child: Text(l.label))).toList(),
          )
        else
          Row(children: links),
      ],
    );
  }
}

class _NavLink extends StatelessWidget {
  const _NavLink(this.label, this.path);
  final String label;
  final String path;
  @override
  Widget build(BuildContext context) => TextButton(
        onPressed: () => context.go(path),
        child: Text(label, style: const TextStyle(color: Colors.white70)),
      );
}
