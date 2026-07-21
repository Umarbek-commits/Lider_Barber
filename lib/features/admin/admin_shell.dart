import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../data/providers.dart';
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

  static const _tabs = [DashboardTab(), ScheduleTab(), ClientsTab(), SettingsTab()];
  static const _destinations = [
    (icon: Icons.dashboard_outlined, selected: Icons.dashboard, label: 'Дашборд'),
    (icon: Icons.calendar_month_outlined, selected: Icons.calendar_month, label: 'Расписание'),
    (icon: Icons.people_outline, selected: Icons.people, label: 'Клиенты'),
    (icon: Icons.settings_outlined, selected: Icons.settings, label: 'Настройки'),
  ];

  Future<void> _signOut() async {
    await ref.read(authControllerProvider).signOut();
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: Text('${BusinessInfo.name} • панель'),
        actions: [
          if (user != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                  child: Text(user.phone,
                      style: const TextStyle(color: Colors.white54, fontSize: 13))),
            ),
          IconButton(
              onPressed: _signOut, icon: const Icon(Icons.logout_rounded), tooltip: 'Выйти'),
        ],
      ),
      // Same bottom NavigationBar style as the client app (via app theme).
      body: SafeArea(child: IndexedStack(index: _index, children: _tabs)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: _destinations
            .map((d) => NavigationDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.selected),
                  label: d.label,
                ))
            .toList(),
      ),
    );
  }
}
