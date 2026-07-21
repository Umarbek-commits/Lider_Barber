import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../data/booking_repository.dart';
import '../../data/providers.dart';
import '../../models/service.dart';

/// Five-step booking wizard: service → date → time → details → confirmation.
/// Data-driven: services and free slots come from the repositories; on submit
/// it calls the server (which enforces the no-double-booking rule).
class BookingWizard extends ConsumerStatefulWidget {
  const BookingWizard({super.key, this.initialService});

  final Service? initialService;

  @override
  ConsumerState<BookingWizard> createState() => _BookingWizardState();
}

class _BookingWizardState extends ConsumerState<BookingWizard> {
  int _step = 0;
  Service? _service;
  DateTime? _date;
  DateTime? _slot;
  bool _submitting = false;
  BookingOutcome? _outcome;

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _commentCtrl = TextEditingController();

  static final _steps = ['Услуга', 'Дата', 'Время', 'Данные', 'Готово'];

  @override
  void initState() {
    super.initState();
    _service = widget.initialService;
    if (_service != null) _step = 1;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  void _go(int step) => setState(() => _step = step);

  Future<void> _submit() async {
    if (_service == null || _date == null || _slot == null) return;
    if (_nameCtrl.text.trim().isEmpty || _phoneCtrl.text.trim().isEmpty) return;
    setState(() => _submitting = true);
    final outcome = await ref.read(bookingRepositoryProvider).createBooking(
          serviceId: _service!.id,
          date: _date!,
          start: _slot!,
          name: _nameCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          comment: _commentCtrl.text.trim().isEmpty ? null : _commentCtrl.text.trim(),
        );
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _outcome = outcome;
      _step = 4;
    });
    // On a taken slot, invalidate the cached slots so the UI refreshes on retry.
    if (outcome == BookingOutcome.slotTaken && _date != null) {
      ref.invalidate(availableSlotsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 760;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _indicator(isMobile),
          const SizedBox(height: 20),
          switch (_step) {
            0 => _serviceStep(isMobile),
            1 => _dateStep(isMobile),
            2 => _timeStep(isMobile),
            3 => _detailsStep(isMobile),
            _ => _confirmationStep(),
          },
        ],
      ),
    );
  }

  Widget _indicator(bool isMobile) {
    final row = Row(
      children: List.generate(_steps.length, (i) {
        final active = i <= _step;
        final chip = Container(
          margin: EdgeInsets.only(right: i == _steps.length - 1 ? 0 : 8),
          padding: EdgeInsets.symmetric(vertical: 10, horizontal: isMobile ? 12 : 8),
          decoration: BoxDecoration(
            color: active ? AppColors.gold : Colors.white10,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _steps[i],
            style: TextStyle(
              color: active ? Colors.black : Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
        return isMobile ? chip : Expanded(child: Center(child: chip));
      }),
    );
    return isMobile
        ? SingleChildScrollView(scrollDirection: Axis.horizontal, child: row)
        : row;
  }

  // Step 0 — service.
  Widget _serviceStep(bool isMobile) {
    final services = ref.watch(servicesProvider);
    return services.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Text('Не удалось загрузить услуги: $e'),
      data: (list) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Выберите услугу',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: list.map((s) {
              final selected = _service?.id == s.id;
              return GestureDetector(
                onTap: () => setState(() => _service = s),
                child: Container(
                  width: isMobile ? double.infinity : 240,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.surfaceRaised : const Color(0xFF161616),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: selected ? AppColors.gold : Colors.white12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Text(s.priceLabel,
                          style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text('${s.durationMin} мин', style: const TextStyle(color: Colors.white60)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _service == null ? null : () => _go(1),
            child: const Text('Далее'),
          ),
        ],
      ),
    );
  }

  // Step 1 — date (next 14 days, working days only).
  Widget _dateStep(bool isMobile) {
    final today = DateTime.now();
    final days = List.generate(14, (i) => DateTime(today.year, today.month, today.day + i));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Выберите дату',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: days.map((d) {
            final works = ref.watch(worksOnDateProvider(d)).value ?? true;
            final selected = _date != null && DateUtils.isSameDay(_date, d);
            return ChoiceChip(
              label: Text(DateFormat('E d.MM', 'ru').format(d)),
              selected: selected,
              onSelected: works
                  ? (_) => setState(() {
                        _date = d;
                        _slot = null;
                      })
                  : null,
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        _nav(isMobile, onBack: () => _go(0), onNext: _date == null ? null : () => _go(2)),
      ],
    );
  }

  // Step 2 — time (computed slots).
  Widget _timeStep(bool isMobile) {
    final query = (
      serviceId: _service!.id,
      durationMin: _service!.durationMin,
      date: _date!,
    );
    final slots = ref.watch(availableSlotsProvider(query));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Свободное время • ${DateFormat('d MMMM', 'ru').format(_date!)}',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        slots.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text('Не удалось загрузить слоты: $e'),
          data: (list) => list.isEmpty
              ? const Text('На эту дату свободных слотов нет. Выберите другой день.',
                  style: TextStyle(color: Colors.white70))
              : Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: list.map((t) {
                    final selected = _slot != null &&
                        _slot!.hour == t.hour &&
                        _slot!.minute == t.minute;
                    return ChoiceChip(
                      label: Text(DateFormat.Hm().format(t)),
                      selected: selected,
                      onSelected: (_) => setState(() => _slot = t),
                    );
                  }).toList(),
                ),
        ),
        const SizedBox(height: 20),
        _nav(isMobile, onBack: () => _go(1), onNext: _slot == null ? null : () => _go(3)),
      ],
    );
  }

  // Step 3 — customer details.
  Widget _detailsStep(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Ваши данные',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        TextField(
          controller: _nameCtrl,
          decoration: const InputDecoration(labelText: 'Имя', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _phoneCtrl,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
              labelText: 'Телефон', hintText: '+996 555 12 34 56', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _commentCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
              labelText: 'Комментарий (необязательно)', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 20),
        _nav(
          isMobile,
          onBack: () => _go(2),
          nextLabel: 'Подтвердить',
          onNext: _submitting ? null : _submit,
          loading: _submitting,
        ),
      ],
    );
  }

  // Step 4 — result.
  Widget _confirmationStep() {
    final ok = _outcome == BookingOutcome.success;
    final (icon, color, title, subtitle) = switch (_outcome) {
      BookingOutcome.success => (
          Icons.check_circle_outline_rounded,
          AppColors.gold,
          'Вы записаны!',
          '${DateFormat('d MMMM, EEEE', 'ru').format(_date!)} — ${DateFormat.Hm().format(_slot!)}',
        ),
      BookingOutcome.slotTaken => (
          Icons.error_outline_rounded,
          Colors.orangeAccent,
          'Это время уже заняли',
          'Пожалуйста, вернитесь и выберите другой слот.',
        ),
      BookingOutcome.blacklisted => (
          Icons.block_rounded,
          Colors.redAccent,
          'Запись недоступна',
          'Свяжитесь с барбершопом напрямую.',
        ),
      BookingOutcome.notConfigured => (
          Icons.info_outline_rounded,
          Colors.white70,
          'Демо-режим',
          'Backend не подключён — запись не сохранена. Настройте Supabase для реальных броней.',
        ),
      _ => (
          Icons.error_outline_rounded,
          Colors.redAccent,
          'Что-то пошло не так',
          'Попробуйте ещё раз позже.',
        ),
    };
    return Column(
      children: [
        Icon(icon, size: 56, color: color),
        const SizedBox(height: 12),
        Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
        if (ok) ...[
          const SizedBox(height: 8),
          Text(_service?.name ?? '', style: const TextStyle(color: AppColors.gold)),
        ],
        const SizedBox(height: 16),
        if (!ok)
          FilledButton(
            onPressed: () => _go(_outcome == BookingOutcome.slotTaken ? 2 : 0),
            child: const Text('Назад к выбору'),
          )
        else
          OutlinedButton(
            onPressed: () => setState(() {
              _step = 0;
              _service = null;
              _date = null;
              _slot = null;
              _outcome = null;
              _nameCtrl.clear();
              _phoneCtrl.clear();
              _commentCtrl.clear();
            }),
            child: const Text('Новая запись'),
          ),
      ],
    );
  }

  Widget _nav(bool isMobile,
      {VoidCallback? onBack,
      VoidCallback? onNext,
      String nextLabel = 'Далее',
      bool loading = false}) {
    final next = FilledButton(
      onPressed: onNext,
      child: loading
          ? const SizedBox(
              width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
          : Text(nextLabel),
    );
    return Flex(
      direction: isMobile ? Axis.vertical : Axis.horizontal,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton(onPressed: onBack, child: const Text('Назад')),
        SizedBox(width: isMobile ? 0 : 12, height: isMobile ? 12 : 0),
        next,
      ],
    );
  }
}
