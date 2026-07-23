import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/constants.dart';
import '../../data/providers.dart';
import '../../shared/widgets/theme_toggle.dart';
import '../auth/auth_controller.dart';
import 'tabs/clients_tab.dart';
import 'tabs/dashboard_tab.dart';
import 'tabs/schedule_tab.dart';
import 'tabs/settings_tab.dart';

/// Admin panel shell — dashboard, schedule, clients, settings. Reachable only
/// by an authenticated admin (enforced by the router guard + RLS).
class AdminShell extends ConsumerStatefulWidget {
  const AdminShell({super.key});

  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell> {
  int _index = 0;

  Future<void> _signOut() async {
    await ref.read(authControllerProvider).signOut();
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;
    final isAdmin = user?.isAdmin ?? false;

    // Barbers see everything except Settings (schedule config, masters, news).
    final tabs = <Widget>[
      const DashboardTab(),
      const ScheduleTab(),
      const ClientsTab(),
      if (isAdmin) const SettingsTab(),
    ];
    final destinations = <NavigationDestination>[
      const NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard),
          label: 'Дашборд'),
      const NavigationDestination(
          icon: Icon(Icons.calendar_month_outlined),
          selectedIcon: Icon(Icons.calendar_month),
          label: 'Расписание'),
      const NavigationDestination(
          icon: Icon(Icons.people_outline),
          selectedIcon: Icon(Icons.people),
          label: 'Клиенты'),
      if (isAdmin)
        const NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Настройки'),
    ];

    final safeIndex = _index.clamp(0, tabs.length - 1);

    return Scaffold(
      appBar: AppBar(
        title: Text('${BusinessInfo.name} • панель'),
        actions: [
          if (user != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                  child: Text(user.name ?? user.phone,
                      style: TextStyle(color: context.faint, fontSize: 13))),
            ),
          const ThemeToggle(),
          IconButton(
              onPressed: _signOut, icon: const Icon(Icons.logout_rounded), tooltip: 'Выйти'),
        ],
      ),
      body: SafeArea(child: IndexedStack(index: safeIndex, children: tabs)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: safeIndex,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: destinations,
      ),
    );
  }
}
