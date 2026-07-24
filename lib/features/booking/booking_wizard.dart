import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../core/pricing.dart';
import '../../core/supabase_client.dart';
import '../../data/booking_repository.dart';
import '../../data/providers.dart';
import '../../l10n/l10n.dart';
import '../../models/service.dart';
import '../../shared/widgets/skeleton.dart';
import '../auth/auth_controller.dart';

/// Five-step booking wizard, gated behind Google sign-in: service → date →
/// time → details → confirmation. Name/phone are prefilled from the account.
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
  bool _prefilled = false;
  BookingOutcome? _outcome;

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _commentCtrl = TextEditingController();
  final _promoCtrl = TextEditingController();
  int _promoDiscount = 0;
  String? _promoMsg;
  bool _checkingPromo = false;

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
    _promoCtrl.dispose();
    super.dispose();
  }

  Future<void> _applyPromo(T t) async {
    final code = _promoCtrl.text.trim();
    if (code.isEmpty) return;
    setState(() => _checkingPromo = true);
    try {
      final res = await supabase.rpc('promo_discount', params: {'p_code': code});
      final discount = (res as num?)?.toInt() ?? 0;
      setState(() {
        _promoDiscount = discount;
        _promoMsg = discount > 0 ? t.promoApplied(discount) : t.promoInvalid;
      });
    } catch (_) {
      setState(() => _promoMsg = t.promoInvalid);
    } finally {
      if (mounted) setState(() => _checkingPromo = false);
    }
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
          promoCode: _promoCtrl.text.trim().isEmpty ? null : _promoCtrl.text.trim(),
        );
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _outcome = outcome;
      _step = 4;
    });
    if (outcome == BookingOutcome.success) {
      ref.invalidate(myBookingsProvider);
    }
    if (outcome == BookingOutcome.slotTaken) {
      ref.invalidate(availableSlotsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final user = ref.watch(currentUserProvider).value;
    final isMobile = MediaQuery.of(context).size.width < 760;

    // Booking requires a signed-in client.
    if (user == null) {
      return _loginGate(t);
    }

    // Prefill name (Google) + phone (remembered) once.
    if (!_prefilled) {
      _prefilled = true;
      _nameCtrl.text = authDisplayName ?? user.name ?? '';
      _phoneCtrl.text = user.contactPhone ?? '';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _indicator(t, isMobile),
          const SizedBox(height: 20),
          switch (_step) {
            0 => _serviceStep(t, isMobile),
            1 => _dateStep(t, isMobile),
            2 => _timeStep(t, isMobile),
            3 => _detailsStep(t, isMobile),
            _ => _confirmationStep(t),
          },
        ],
      ),
    );
  }

  Widget _loginGate(T t) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.border),
      ),
      child: Column(
        children: [
          const Icon(Icons.lock_outline_rounded, size: 40, color: AppColors.gold),
          const SizedBox(height: 12),
          Text(t.loginToBook,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => ref.read(authControllerProvider).signInWithGoogle(),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              side: BorderSide(color: context.border),
            ),
            icon: const Text('G', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            label: Text(t.signInGoogle),
          ),
        ],
      ),
    );
  }

  Widget _indicator(T t, bool isMobile) {
    final steps = t.steps;
    final row = Row(
      children: List.generate(steps.length, (i) {
        final active = i <= _step;
        final chip = Container(
          margin: EdgeInsets.only(right: i == steps.length - 1 ? 0 : 8),
          padding: EdgeInsets.symmetric(vertical: 10, horizontal: isMobile ? 12 : 8),
          decoration: BoxDecoration(
            color: active ? AppColors.gold : context.border,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(steps[i],
              style: TextStyle(
                  color: active ? Colors.black : context.muted, fontWeight: FontWeight.w600)),
        );
        return isMobile ? chip : Expanded(child: Center(child: chip));
      }),
    );
    return isMobile
        ? SingleChildScrollView(scrollDirection: Axis.horizontal, child: row)
        : row;
  }

  Widget _serviceStep(T t, bool isMobile) {
    final services = ref.watch(servicesProvider);
    return services.when(
      loading: () => const SkeletonList(count: 4, cardHeight: 88),
      error: (e, _) => Text(t.error(e)),
      data: (list) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.chooseService, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.nightlight_round, size: 14, color: AppColors.gold),
              const SizedBox(width: 6),
              Text('С 20:00 до 23:00 ко всем услугам +$eveningSurchargeSom сом',
                  style: TextStyle(color: context.faint, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: list.map((s) {
              final selected = _service?.id == s.id;
              return GestureDetector(
                onTap: () {
                  setState(() => _service = s);
                  _go(1); // auto-advance to date
                },
                child: Container(
                  width: isMobile ? double.infinity : 220,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: selected ? context.surfaceAlt : context.surfaceAlt,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: selected ? AppColors.gold : context.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.name,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(s.priceLabel,
                              style: const TextStyle(
                                  color: AppColors.gold,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13)),
                          SizedBox(width: 10),
                          Text('${s.durationMin} ${t.minutesShort}',
                              style: TextStyle(color: context.faint, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _dateStep(T t, bool isMobile) {
    final today = DateTime.now();
    final days = List.generate(14, (i) => DateTime(today.year, today.month, today.day + i));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t.chooseDate, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
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
                  ? (_) {
                      setState(() {
                        _date = d;
                        _slot = null;
                      });
                      _go(2); // auto-advance to time
                    }
                  : null,
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        _backButton(t, () => _go(0)),
      ],
    );
  }

  Widget _timeStep(T t, bool isMobile) {
    final query = (serviceId: _service!.id, durationMin: _service!.durationMin, date: _date!);
    final slots = ref.watch(availableSlotsProvider(query));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${t.freeTime} • ${DateFormat('d MMMM', 'ru').format(_date!)}',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        slots.when(
          loading: () => const Padding(
              padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator())),
          error: (e, _) => Text(t.error(e)),
          data: (list) => list.isEmpty
              ? Text(t.noSlots, style: TextStyle(color: context.muted))
              : Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: list.map((tm) {
                    final selected =
                        _slot != null && _slot!.hour == tm.hour && _slot!.minute == tm.minute;
                    return ChoiceChip(
                      label: Text(DateFormat.Hm().format(tm)),
                      selected: selected,
                      onSelected: (_) {
                        setState(() => _slot = tm);
                        _go(3); // auto-advance to details
                      },
                    );
                  }).toList(),
                ),
        ),
        const SizedBox(height: 20),
        _backButton(t, () => _go(1)),
      ],
    );
  }

  Widget _detailsStep(T t, bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t.yourData, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        TextField(
          controller: _nameCtrl,
          decoration: InputDecoration(labelText: t.name, border: const OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _phoneCtrl,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
              labelText: t.phone, hintText: '+996 555 12 34 56', border: const OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _commentCtrl,
          maxLines: 3,
          decoration: InputDecoration(labelText: t.comment, border: const OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _promoCtrl,
          textCapitalization: TextCapitalization.characters,
          onChanged: (_) => setState(() {
            _promoDiscount = 0;
            _promoMsg = null;
          }),
          decoration: InputDecoration(
            labelText: t.promoField,
            border: const OutlineInputBorder(),
            suffixIcon: TextButton(
              onPressed: _checkingPromo ? null : () => _applyPromo(t),
              child: _checkingPromo
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('OK'),
            ),
          ),
        ),
        if (_promoMsg != null) ...[
          const SizedBox(height: 6),
          Text(_promoMsg!,
              style: TextStyle(
                  color: _promoDiscount > 0 ? AppColors.gold : Colors.redAccent, fontSize: 13)),
        ],
        const SizedBox(height: 20),
        _nav(t, isMobile,
            onBack: () => _go(2),
            nextLabel: t.confirm,
            onNext: _submitting ? null : _submit,
            loading: _submitting),
      ],
    );
  }

  Widget _confirmationStep(T t) {
    final ok = _outcome == BookingOutcome.success;
    final (icon, color, title, subtitle) = switch (_outcome) {
      BookingOutcome.success => (
          Icons.check_circle_outline_rounded,
          AppColors.gold,
          t.booked,
          '${DateFormat('d MMMM, EEEE', 'ru').format(_date!)} — ${DateFormat.Hm().format(_slot!)}',
        ),
      BookingOutcome.slotTaken => (
          Icons.error_outline_rounded,
          Colors.orangeAccent,
          t.slotTakenTitle,
          t.slotTakenText,
        ),
      BookingOutcome.blacklisted => (
          Icons.block_rounded,
          Colors.redAccent,
          t.blockedTitle,
          t.blockedText,
        ),
      BookingOutcome.notConfigured => (
          Icons.info_outline_rounded,
          context.muted,
          'Demo',
          '',
        ),
      _ => (Icons.error_outline_rounded, Colors.redAccent, t.errorTitle, t.errorText),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 56, color: color),
        const SizedBox(height: 12),
        Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        SizedBox(height: 8),
        Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: context.muted)),
        if (ok) ...[
          const SizedBox(height: 8),
          Text(_service?.name ?? '', style: const TextStyle(color: AppColors.gold)),
          if (_service != null && _slot != null) ...[
            const SizedBox(height: 4),
            Builder(builder: (_) {
              final extra = eveningSurcharge(_slot);
              final total = _service!.priceSom + extra - _promoDiscount;
              final parts = <String>[
                if (extra > 0) 'вечерняя доплата +$extra',
                if (_promoDiscount > 0) 'промокод −$_promoDiscount',
              ];
              return Text(
                parts.isEmpty ? '$total сом' : '$total сом (${parts.join(', ')})',
                style: TextStyle(color: context.muted, fontSize: 13),
              );
            }),
          ],
        ],
        const SizedBox(height: 16),
        if (!ok)
          FilledButton(
            onPressed: () => _go(_outcome == BookingOutcome.slotTaken ? 2 : 0),
            child: Text(t.backToChoice),
          )
        else
          OutlinedButton(
            onPressed: () => setState(() {
              _step = 0;
              _service = null;
              _date = null;
              _slot = null;
              _outcome = null;
              _commentCtrl.clear();
            }),
            child: Text(t.newBooking),
          ),
        ],
      ),
    );
  }

  Widget _backButton(T t, VoidCallback onBack) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(onPressed: onBack, child: Text(t.back)),
    );
  }

  Widget _nav(T t, bool isMobile,
      {VoidCallback? onBack, VoidCallback? onNext, String? nextLabel, bool loading = false}) {
    final next = FilledButton(
      onPressed: onNext,
      child: loading
          ? const SizedBox(
              width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
          : Text(nextLabel ?? t.next),
    );
    return Flex(
      direction: isMobile ? Axis.vertical : Axis.horizontal,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton(onPressed: onBack, child: Text(t.back)),
        SizedBox(width: isMobile ? 0 : 12, height: isMobile ? 12 : 0),
        next,
      ],
    );
  }
}
