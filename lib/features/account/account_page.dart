import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../data/providers.dart';
import '../../l10n/l10n.dart';
import '../../models/booking.dart';
import '../../models/booking_status.dart';
import '../auth/auth_controller.dart';
import '../push/push_button.dart';
import '../../shared/widgets/page_shell.dart';
import '../../shared/widgets/skeleton.dart';
import '../../shared/widgets/stars.dart';

/// Client cabinet: upcoming bookings (with cancel) and visit history (with repeat).
class AccountPage extends ConsumerWidget {
  const AccountPage({super.key});

  static DateTime _startOf(Booking b) {
    final p = b.startTime.split(':');
    return DateTime(b.bookingDate.year, b.bookingDate.month, b.bookingDate.day,
        int.parse(p[0]), int.parse(p[1]));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final bookings = ref.watch(myBookingsProvider);
    final user = ref.watch(currentUserProvider).value;

    return PageShell(
      onRefresh: () async {
        ref.invalidate(myBookingsProvider);
        await ref.read(myBookingsProvider.future);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(t.myBookings,
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
              ),
              const PushBell(),
              IconButton(
                onPressed: () => ref.invalidate(myBookingsProvider),
                icon: const Icon(Icons.refresh_rounded),
                tooltip: t.refresh,
              ),
              TextButton.icon(
                onPressed: () async {
                  await ref.read(authControllerProvider).signOut();
                  if (context.mounted) context.go('/');
                },
                icon: const Icon(Icons.logout_rounded),
                label: Text(t.signOut),
              ),
            ],
          ),
          if (user != null)
            Text(user.name ?? user.phone, style: TextStyle(color: context.faint)),
          const SizedBox(height: 20),
          bookings.when(
            loading: () => const SkeletonList(count: 3, cardHeight: 64),
            error: (e, _) => Text(t.error(e)),
            data: (list) => _content(context, ref, t, list),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _content(BuildContext context, WidgetRef ref, T t, List<Booking> list) {
    final now = DateTime.now();
    final upcoming = list
        .where((b) =>
            _startOf(b).isAfter(now) &&
            (b.status == BookingStatus.pending || b.status == BookingStatus.confirmed))
        .toList()
      ..sort((a, b) => _startOf(a).compareTo(_startOf(b)));
    final history = list.where((b) => !upcoming.contains(b)).toList();

    if (list.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.noBookings, style: TextStyle(color: context.muted)),
          SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => context.go('/book'),
            icon: const Icon(Icons.add),
            label: Text(t.bookAction),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (upcoming.isNotEmpty) ...[
          _Header(t.upcoming),
          ...upcoming.map((b) => _BookingCard(
                booking: b,
                statusLabel: t.status(b.status),
                trailing: TextButton(
                  style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                  onPressed: () => _cancel(context, ref, t, b),
                  child: Text(t.cancel),
                ),
              )),
          const SizedBox(height: 24),
        ],
        if (history.isNotEmpty) ...[
          _Header(t.history),
          ...history.map((b) => _BookingCard(
                booking: b,
                statusLabel: t.status(b.status),
                trailing: TextButton(
                  onPressed: () => context.go('/book?service=${b.serviceId}'),
                  child: Text(t.repeat),
                ),
                footer: _ratingFooter(context, ref, t, b),
              )),
        ],
      ],
    );
  }

  /// Rating row for a completed visit: shows given stars, or an "Оценить" button.
  Widget? _ratingFooter(BuildContext context, WidgetRef ref, T t, Booking b) {
    if (b.status != BookingStatus.completed) return null;
    if (b.rating != null) {
      return Row(
        children: [
          Stars(rating: b.rating!),
          if ((b.review ?? '').isNotEmpty) ...[
            SizedBox(width: 8),
            Expanded(
              child: Text('«${b.review}»',
                  style: TextStyle(color: context.faint, fontSize: 12),
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ],
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        onPressed: () => _rate(context, ref, t, b),
        icon: const Icon(Icons.star_border_rounded, size: 18),
        label: Text(t.rate),
      ),
    );
  }

  Future<void> _rate(BuildContext context, WidgetRef ref, T t, Booking b) async {
    final done = await showDialog<bool>(
      context: context,
      builder: (_) => _RateDialog(booking: b, t: t),
    );
    if (done == true) ref.invalidate(myBookingsProvider);
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref, T t, Booking b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.surface,
        title: Text(t.cancelQuestion),
        content: Text(
            '${DateFormat('d MMMM, EEEE', 'ru').format(b.bookingDate)} — ${b.startTime}\n${b.serviceName ?? ''}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t.no)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: Text(t.cancelYes),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(clientRepositoryProvider).cancel(b.id);
      ref.invalidate(myBookingsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${t.cancelFailed}: $e')));
      }
    }
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(text,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.gold)),
      );
}

class _BookingCard extends StatelessWidget {
  const _BookingCard(
      {required this.booking, required this.statusLabel, required this.trailing, this.footer});
  final Booking booking;
  final String statusLabel;
  final Widget trailing;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${DateFormat('d MMMM, EEEE', 'ru').format(booking.bookingDate)} • ${booking.startTime}',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 4),
                    Text('${booking.serviceName ?? ''} — $statusLabel',
                        style: TextStyle(color: context.faint, fontSize: 13)),
                  ],
                ),
              ),
              trailing,
            ],
          ),
          if (footer != null) ...[
            Divider(height: 18, color: context.border),
            footer!,
          ],
        ],
      ),
    );
  }
}

/// Star + review dialog for a completed visit.
class _RateDialog extends ConsumerStatefulWidget {
  const _RateDialog({required this.booking, required this.t});
  final Booking booking;
  final T t;

  @override
  ConsumerState<_RateDialog> createState() => _RateDialogState();
}

class _RateDialogState extends ConsumerState<_RateDialog> {
  int _rating = 5;
  final _review = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _review.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    return AlertDialog(
      backgroundColor: context.surface,
      title: Text(t.rateVisit),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.booking.acceptedByName != null) ...[
              Text('Мастер: ${widget.booking.acceptedByName}',
                  style: TextStyle(color: context.faint)),
              const SizedBox(height: 8),
            ],
            StarPicker(value: _rating, onChanged: (v) => setState(() => _rating = v)),
            const SizedBox(height: 12),
            TextField(
              controller: _review,
              maxLines: 3,
              decoration: InputDecoration(labelText: t.reviewHint, border: const OutlineInputBorder()),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t.no)),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
              : Text(t.send),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      await ref.read(clientRepositoryProvider).leaveReview(
            bookingId: widget.booking.id,
            rating: _rating,
            review: _review.text.trim().isEmpty ? null : _review.text.trim(),
          );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _busy = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.t.error(e))));
      }
    }
  }
}
