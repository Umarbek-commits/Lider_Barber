import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../data/admin_providers.dart';
import '../../../models/schedule_exception.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../../shared/widgets/time_button.dart';

class ExceptionsPage extends ConsumerWidget {
  const ExceptionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exceptions = ref.watch(adminExceptionsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Исключения')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Добавить'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Разовые изменения на конкретную дату (выходной или другие часы).',
              style: TextStyle(color: Colors.white60)),
          const SizedBox(height: 12),
          exceptions.when(
            loading: () => const SkeletonList(count: 3, cardHeight: 52),
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
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final added =
        await showDialog<bool>(context: context, builder: (_) => const _AddExceptionDialog());
    if (added == true) ref.invalidate(adminExceptionsProvider);
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
          IconButton(
              onPressed: onDelete, icon: const Icon(Icons.delete_outline, color: Colors.redAccent)),
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
              label: Text(_date == null
                  ? 'Выбрать дату'
                  : DateFormat('d MMMM y', 'ru').format(_date!)),
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
                  TimeButton(label: _start, onPick: (t) => setState(() => _start = t)),
                  const Text('  –  '),
                  TimeButton(label: _end, onPick: (t) => setState(() => _end = t)),
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
              ? const SizedBox(
                  width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
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
