import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../data/admin_providers.dart';
import '../../../models/schedule.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../../shared/widgets/time_button.dart';

const weekdayNames = {
  1: 'Понедельник',
  2: 'Вторник',
  3: 'Среда',
  4: 'Четверг',
  5: 'Пятница',
  6: 'Суббота',
  7: 'Воскресенье',
};

class WorkingHoursPage extends ConsumerWidget {
  const WorkingHoursPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedules = ref.watch(adminSchedulesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Рабочий график')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Часы работы по дням недели.', style: TextStyle(color: context.faint)),
          const SizedBox(height: 12),
          schedules.when(
            loading: () => const SkeletonList(count: 7, cardHeight: 72),
            error: (e, _) => Text('Ошибка: $e'),
            data: (list) {
              final byWeekday = {for (final s in list) s.weekday: s};
              return Column(
                children: List.generate(
                    7, (i) => _WeekdayRow(weekday: i + 1, schedule: byWeekday[i + 1])),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _WeekdayRow extends ConsumerWidget {
  const _WeekdayRow({required this.weekday, required this.schedule});
  final int weekday;
  final Schedule? schedule;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDayOff = schedule?.isDayOff ?? false;
    final start = schedule?.startTime ?? '10:00';
    final end = schedule?.endTime ?? '20:00';

    Future<void> save({bool? dayOff, String? s, String? e}) async {
      await ref.read(adminRepositoryProvider).upsertSchedule(
            weekday: weekday,
            isDayOff: dayOff ?? isDayOff,
            start: s ?? start,
            end: e ?? end,
            breakStart: schedule?.breakStart,
            breakEnd: schedule?.breakEnd,
          );
      ref.invalidate(adminSchedulesProvider);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(weekdayNames[weekday]!,
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
              Text('Выходной',
                  style: TextStyle(
                      color: isDayOff ? AppColors.gold : context.fainter, fontSize: 12)),
              Switch(value: isDayOff, onChanged: (v) => save(dayOff: v)),
            ],
          ),
          if (!isDayOff)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 4),
              child: Row(
                children: [
                  TimeButton(label: start, onPick: (t) => save(s: t)),
                  Text('  –  ', style: TextStyle(color: context.fainter)),
                  TimeButton(label: end, onPick: (t) => save(e: t)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
