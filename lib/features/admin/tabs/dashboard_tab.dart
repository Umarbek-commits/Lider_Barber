import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../data/admin_providers.dart';
import '../../../data/admin_repository.dart';

class DashboardTab extends ConsumerWidget {
  const DashboardTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final ranges = <String, DateRange>{
      'Сегодня': (from: today, to: today),
      'Неделя': (from: today.subtract(const Duration(days: 6)), to: today),
      'Месяц': (from: today.subtract(const Duration(days: 29)), to: today),
    };

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Дашборд', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        const Text('Клиенты и доход. Доход считается по выполненным записям.',
            style: TextStyle(color: Colors.white60)),
        const SizedBox(height: 20),
        ...ranges.entries.map((e) => _StatsBlock(title: e.key, range: e.value)),
      ],
    );
  }
}

class _StatsBlock extends ConsumerWidget {
  const _StatsBlock({required this.title, required this.range});
  final String title;
  final DateRange range;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(dashboardStatsProvider(range));
    final value = stats.value ?? DashboardStats.empty;
    final loading = stats.isLoading;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  label: 'Клиентов',
                  value: loading ? '…' : '${value.clients}',
                ),
              ),
              Expanded(
                child: _Metric(
                  label: 'Доход, сом',
                  value: loading ? '…' : '${value.revenue}',
                  highlight: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, this.highlight = false});
  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: highlight ? AppColors.gold : Colors.white,
              )),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white60)),
        ],
      );
}
