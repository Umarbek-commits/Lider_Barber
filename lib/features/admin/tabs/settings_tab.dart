import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../pages/exceptions_page.dart';
import '../pages/masters_page.dart';
import '../pages/news_page.dart';
import '../pages/services_admin_page.dart';
import '../pages/working_hours_page.dart';

/// Settings menu — each item opens its own page.
class SettingsTab extends ConsumerWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = <_SettingsItem>[
      _SettingsItem(
        icon: Icons.content_cut,
        title: 'Мастера',
        subtitle: 'Добавить барберов и управлять доступом',
        page: const MastersPage(),
      ),
      _SettingsItem(
        icon: Icons.design_services,
        title: 'Услуги',
        subtitle: 'Услуги, цены и длительность',
        page: const ServicesAdminPage(),
      ),
      _SettingsItem(
        icon: Icons.schedule,
        title: 'Рабочий график',
        subtitle: 'Часы работы по дням недели',
        page: const WorkingHoursPage(),
      ),
      _SettingsItem(
        icon: Icons.event_busy,
        title: 'Исключения',
        subtitle: 'Выходные и особые часы на дату',
        page: const ExceptionsPage(),
      ),
      _SettingsItem(
        icon: Icons.campaign,
        title: 'Новости',
        subtitle: 'Объявления для клиентов на главной',
        page: const NewsPage(),
      ),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 12),
          child: Text('Настройки', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
        ),
        ...items.map((it) => _SettingsRow(item: it)),
      ],
    );
  }
}

class _SettingsItem {
  const _SettingsItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.page,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget page;
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({required this.item});
  final _SettingsItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: AppColors.gold.withValues(alpha: 0.15),
          child: Icon(item.icon, color: AppColors.gold, size: 20),
        ),
        title: Text(item.title, style: TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(item.subtitle, style: TextStyle(color: context.faint, fontSize: 12)),
        trailing: Icon(Icons.chevron_right, color: context.fainter),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => item.page),
        ),
      ),
    );
  }
}
