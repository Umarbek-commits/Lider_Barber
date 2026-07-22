import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../data/admin_providers.dart';
import '../../../data/providers.dart';
import '../../../models/booking.dart';
import '../../../models/booking_status.dart';
import '../../../models/service.dart';
import '../../../shared/widgets/skeleton.dart';

class ScheduleTab extends ConsumerStatefulWidget {
  const ScheduleTab({super.key});

  @override
  ConsumerState<ScheduleTab> createState() => _ScheduleTabState();
}

class _ScheduleTabState extends ConsumerState<ScheduleTab> {
  late DateTime _day;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _day = DateTime(now.year, now.month, now.day);
  }

  void _shift(int days) => setState(() => _day = _day.add(Duration(days: days)));

  Future<void> _mutate(Future<void> Function() action) async {
    try {
      await action();
      ref.invalidate(adminBookingsProvider(_day));
    } catch (e) {
      if (mounted) _snack('Ошибка: $e');
    }
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final bookings = ref.watch(adminBookingsProvider(_day));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Row(
            children: [
              IconButton(onPressed: () => _shift(-1), icon: const Icon(Icons.chevron_left)),
              Expanded(
                child: Center(
                  child: Text(DateFormat('EEEE, d MMMM', 'ru').format(_day),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                ),
              ),
              IconButton(onPressed: () => _shift(1), icon: const Icon(Icons.chevron_right)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              TextButton(
                onPressed: () => setState(() {
                  final n = DateTime.now();
                  _day = DateTime(n.year, n.month, n.day);
                }),
                child: const Text('Сегодня'),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => _openAddDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Добавить'),
              ),
            ],
          ),
        ),
        Expanded(
          child: bookings.when(
            loading: () => const Padding(
                padding: EdgeInsets.all(20), child: SkeletonList(count: 5, cardHeight: 72)),
            error: (e, _) => Center(child: Text('Ошибка: $e')),
            data: (list) => list.isEmpty
                ? const Center(child: Text('На этот день записей нет', style: TextStyle(color: Colors.white60)))
                : ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _BookingRow(
                      booking: list[i],
                      onComplete: () => _mutate(() =>
                          ref.read(adminRepositoryProvider).setStatus(list[i].id, BookingStatus.completed)),
                      onConfirm: () => _mutate(() =>
                          ref.read(adminRepositoryProvider).setStatus(list[i].id, BookingStatus.confirmed)),
                      onCancel: () => _mutate(() =>
                          ref.read(adminRepositoryProvider).setStatus(list[i].id, BookingStatus.cancelled)),
                      onNoShow: () => _mutate(() =>
                          ref.read(adminRepositoryProvider).setStatus(list[i].id, BookingStatus.noShow)),
                      onMove: () => _openMoveDialog(list[i]),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Future<void> _openAddDialog() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => _AddBookingDialog(day: _day),
    );
    if (created == true) ref.invalidate(adminBookingsProvider(_day));
  }

  Future<void> _openMoveDialog(Booking b) async {
    final moved = await showDialog<bool>(
      context: context,
      builder: (_) => _MoveBookingDialog(booking: b),
    );
    if (moved == true) {
      ref.invalidate(adminBookingsProvider(_day));
      _snack('Запись перенесена');
    }
  }
}

class _BookingRow extends StatelessWidget {
  const _BookingRow({
    required this.booking,
    required this.onComplete,
    required this.onConfirm,
    required this.onCancel,
    required this.onNoShow,
    required this.onMove,
  });

  final Booking booking;
  final VoidCallback onComplete;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  final VoidCallback onNoShow;
  final VoidCallback onMove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(booking.startTime, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.gold)),
              Text(booking.endTime, style: const TextStyle(fontSize: 12, color: Colors.white38)),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(booking.clientName ?? '—', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('${booking.serviceName ?? ''} • ${booking.clientPhone ?? ''}',
                    style: const TextStyle(color: Colors.white60, fontSize: 13)),
                if ((booking.comment ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.chat_bubble_outline, size: 13, color: Colors.white38),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text('«${booking.comment!.trim()}»',
                            style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontStyle: FontStyle.italic)),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 6),
                _StatusChip(status: booking.status),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (v) => switch (v) {
              'complete' => onComplete(),
              'confirm' => onConfirm(),
              'cancel' => onCancel(),
              'noshow' => onNoShow(),
              'move' => onMove(),
              _ => null,
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'complete', child: Text('Выполнена')),
              PopupMenuItem(value: 'confirm', child: Text('Подтвердить')),
              PopupMenuItem(value: 'move', child: Text('Перенести')),
              PopupMenuItem(value: 'noshow', child: Text('Не пришёл')),
              PopupMenuItem(value: 'cancel', child: Text('Отменить')),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final BookingStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      BookingStatus.completed => Colors.green,
      BookingStatus.confirmed => AppColors.gold,
      BookingStatus.pending => Colors.blueGrey,
      BookingStatus.cancelled => Colors.redAccent,
      BookingStatus.noShow => Colors.deepOrange,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(status.label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

/// Add-booking dialog: service → slot → client details.
class _AddBookingDialog extends ConsumerStatefulWidget {
  const _AddBookingDialog({required this.day});
  final DateTime day;

  @override
  ConsumerState<_AddBookingDialog> createState() => _AddBookingDialogState();
}

class _AddBookingDialogState extends ConsumerState<_AddBookingDialog> {
  Service? _service;
  DateTime? _slot;
  final _name = TextEditingController();
  final _phone = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final services = ref.watch(servicesProvider).value ?? const [];
    final slots = _service == null
        ? const AsyncValue<List<DateTime>>.data([])
        : ref.watch(availableSlotsProvider((
            serviceId: _service!.id,
            durationMin: _service!.durationMin,
            date: widget.day,
          )));

    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('Новая запись'),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<Service>(
                initialValue: _service,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Услуга'),
                items: services
                    .map((s) => DropdownMenuItem(value: s, child: Text('${s.name} • ${s.priceLabel}')))
                    .toList(),
                onChanged: (s) => setState(() {
                  _service = s;
                  _slot = null;
                }),
              ),
              const SizedBox(height: 12),
              if (_service != null)
                slots.when(
                  loading: () => const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator()),
                  error: (e, _) => Text('Слоты: $e'),
                  data: (list) => list.isEmpty
                      ? const Text('Свободных слотов нет', style: TextStyle(color: Colors.white60))
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: list
                              .map((t) => ChoiceChip(
                                    label: Text(DateFormat.Hm().format(t)),
                                    selected: _slot == t,
                                    onSelected: (_) => setState(() => _slot = t),
                                  ))
                              .toList(),
                        ),
                ),
              const SizedBox(height: 12),
              TextField(controller: _name, decoration: const InputDecoration(labelText: 'Имя')),
              const SizedBox(height: 8),
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Телефон'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.redAccent)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
              : const Text('Создать'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (_service == null || _slot == null || _name.text.trim().isEmpty || _phone.text.trim().isEmpty) {
      setState(() => _error = 'Заполните услугу, время, имя и телефон');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(adminRepositoryProvider).createBooking(
            serviceId: _service!.id,
            day: widget.day,
            start: _slot!,
            name: _name.text.trim(),
            phone: _phone.text.trim(),
          );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _busy = false;
        _error = e.toString().contains('slot_taken') ? 'Это время уже занято' : 'Ошибка: $e';
      });
    }
  }
}

/// Move-booking dialog: pick a new working day and a free slot.
class _MoveBookingDialog extends ConsumerStatefulWidget {
  const _MoveBookingDialog({required this.booking});
  final Booking booking;

  @override
  ConsumerState<_MoveBookingDialog> createState() => _MoveBookingDialogState();
}

class _MoveBookingDialogState extends ConsumerState<_MoveBookingDialog> {
  late DateTime _day;
  DateTime? _slot;
  bool _busy = false;
  String? _error;

  int get _durationMin {
    final s = widget.booking.startTime.split(':');
    final e = widget.booking.endTime.split(':');
    return (int.parse(e[0]) * 60 + int.parse(e[1])) - (int.parse(s[0]) * 60 + int.parse(s[1]));
  }

  @override
  void initState() {
    super.initState();
    _day = widget.booking.bookingDate;
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final days = List.generate(14, (i) => DateTime(today.year, today.month, today.day + i));
    final slots = ref.watch(availableSlotsProvider((
      serviceId: widget.booking.serviceId,
      durationMin: _durationMin,
      date: _day,
    )));

    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('Перенести запись'),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Дата', style: TextStyle(color: Colors.white60)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: days.map((d) {
                  final works = ref.watch(worksOnDateProvider(d)).value ?? true;
                  return ChoiceChip(
                    label: Text(DateFormat('E d.MM', 'ru').format(d)),
                    selected: DateUtils.isSameDay(_day, d),
                    onSelected: works ? (_) => setState(() { _day = d; _slot = null; }) : null,
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              const Text('Время', style: TextStyle(color: Colors.white60)),
              const SizedBox(height: 6),
              slots.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Слоты: $e'),
                data: (list) => list.isEmpty
                    ? const Text('Свободных слотов нет', style: TextStyle(color: Colors.white60))
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: list
                            .map((t) => ChoiceChip(
                                  label: Text(DateFormat.Hm().format(t)),
                                  selected: _slot == t,
                                  onSelected: (_) => setState(() => _slot = t),
                                ))
                            .toList(),
                      ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.redAccent)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
              : const Text('Перенести'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (_slot == null) {
      setState(() => _error = 'Выберите время');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(adminRepositoryProvider).moveBooking(
            booking: widget.booking,
            newDate: _day,
            newStart: _slot!,
          );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _busy = false;
        _error = e.toString().contains('overlap') || e.toString().contains('23P01')
            ? 'Это время уже занято'
            : 'Ошибка: $e';
      });
    }
  }
}
