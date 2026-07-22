import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../data/admin_providers.dart';
import '../../../models/schedule.dart';
import '../../../models/schedule_exception.dart';
import '../../../shared/widgets/skeleton.dart';
import 'masters_section.dart';

const _weekdayNames = {
  1: 'Понедельник',
  2: 'Вторник',
  3: 'Среда',
  4: 'Четверг',
  5: 'Пятница',
  6: 'Суббота',
  7: 'Воскресенье',
};

class SettingsTab extends ConsumerWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedules = ref.watch(adminSchedulesProvider);
    final exceptions = ref.watch(adminExceptionsProvider);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const MastersSection(),
        const SizedBox(height: 28),
        const Text('Рабочий график', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        schedules.when(
          loading: () => const SkeletonList(count: 7, cardHeight: 64),
          error: (e, _) => Text('Ошибка: $e'),
          data: (list) {
            final byWeekday = {for (final s in list) s.weekday: s};
            return Column(
              children: List.generate(7, (i) {
                final wd = i + 1;
                return _WeekdayRow(
                  weekday: wd,
                  schedule: byWeekday[wd],
                );
              }),
            );
          },
        ),
        const SizedBox(height: 28),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Исключения', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            FilledButton.icon(
              onPressed: () => _addException(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Добавить'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text('Разовые изменения на конкретную дату (выходной или другие часы).',
            style: TextStyle(color: Colors.white60)),
        const SizedBox(height: 12),
        exceptions.when(
          loading: () => const SkeletonList(count: 2, cardHeight: 52),
          error: (e, _) => Text('Ошибка: $e'),
          data: (list) => list.isEmpty
              ? const Text('Исключений нет', style: TextStyle(color: Colors.white60))
              : Column(
                  children: list
                      .map((e) => _ExceptionRow(
                            exception: e,
                            onDelete: () async {
                              await ref.read(adminRepositoryProvider).deleteException(e.id);
                              ref.invalidate(adminExceptionsProvider);
                            },
                          ))
                      .toList(),
                ),
        ),
      ],
    );
  }

  Future<void> _addException(BuildContext context, WidgetRef ref) async {
    final added = await showDialog<bool>(context: context, builder: (_) => const _AddExceptionDialog());
    if (added == true) ref.invalidate(adminExceptionsProvider);
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

    Future<void> save({bool? dayOff, String? s, String? e, String? bs, String? be}) async {
      await ref.read(adminRepositoryProvider).upsertSchedule(
            weekday: weekday,
            isDayOff: dayOff ?? isDayOff,
            start: s ?? start,
            end: e ?? end,
            breakStart: bs ?? schedule?.breakStart,
            breakEnd: be ?? schedule?.breakEnd,
          );
      ref.invalidate(adminSchedulesProvider);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: weekday name + day-off toggle.
          Row(
            children: [
              Expanded(
                child: Text(_weekdayNames[weekday]!,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              Text('Выходной',
                  style: TextStyle(
                      color: isDayOff ? AppColors.gold : Colors.white38, fontSize: 12)),
              Switch(value: isDayOff, onChanged: (v) => save(dayOff: v)),
            ],
          ),
          // Working hours (only when not a day off).
          if (!isDayOff)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 4),
              child: Row(
                children: [
                  _TimeButton(label: start, onPick: (t) => save(s: t)),
                  const Text('  –  ', style: TextStyle(color: Colors.white38)),
                  _TimeButton(label: end, onPick: (t) => save(e: t)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TimeButton extends StatelessWidget {
  const _TimeButton({required this.label, required this.onPick});
  final String label;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 38),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: () async {
        final parts = label.split(':');
        final picked = await showTimePicker(
          context: context,
          initialTime: TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])),
        );
        if (picked != null) {
          onPick('${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}');
        }
      },
      child: Text(label),
    );
  }
}

class _ExceptionRow extends StatelessWidget {
  const _ExceptionRow({required this.exception, required this.onDelete});
  final ScheduleException exception;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isDayOff = exception.type == ScheduleExceptionType.dayOff;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${DateFormat('d MMMM, EEEE', 'ru').format(exception.date)} — '
              '${isDayOff ? 'выходной' : 'работаю ${exception.startTime}–${exception.endTime}'}',
            ),
          ),
          IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline, color: Colors.redAccent)),
        ],
      ),
    );
  }
}

class _AddExceptionDialog extends ConsumerStatefulWidget {
  const _AddExceptionDialog();

  @override
  ConsumerState<_AddExceptionDialog> createState() => _AddExceptionDialogState();
}

class _AddExceptionDialogState extends ConsumerState<_AddExceptionDialog> {
  DateTime? _date;
  bool _dayOff = true;
  String _start = '10:00';
  String _end = '16:00';
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('Исключение'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OutlinedButton.icon(
              onPressed: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date ?? now,
                  firstDate: now,
                  lastDate: DateTime(now.year + 1),
                );
                if (picked != null) setState(() => _date = picked);
              },
              icon: const Icon(Icons.calendar_today),
              label: Text(_date == null ? 'Выбрать дату' : DateFormat('d MMMM y', 'ru').format(_date!)),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Выходной'),
              value: _dayOff,
              onChanged: (v) => setState(() => _dayOff = v),
            ),
            if (!_dayOff)
              Row(
                children: [
                  _TimeButton(label: _start, onPick: (t) => setState(() => _start = t)),
                  const Text('  –  '),
                  _TimeButton(label: _end, onPick: (t) => setState(() => _end = t)),
                ],
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
        FilledButton(
          onPressed: _busy || _date == null ? null : _save,
          child: _busy
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
              : const Text('Сохранить'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await ref.read(adminRepositoryProvider).addException(
            day: _date!,
            type: _dayOff ? ScheduleExceptionType.dayOff : ScheduleExceptionType.customHours,
            start: _start,
            end: _end,
          );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _busy = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    }
  }
}
