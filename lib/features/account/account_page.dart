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
import '../../shared/widgets/page_shell.dart';
import '../../shared/widgets/skeleton.dart';

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
            Text(user.name ?? user.phone, style: const TextStyle(color: Colors.white60)),
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
          Text(t.noBookings, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 12),
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
              )),
        ],
      ],
    );
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref, T t, Booking b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
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
      {required this.booking, required this.statusLabel, required this.trailing});
  final Booking booking;
  final String statusLabel;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${DateFormat('d MMMM, EEEE', 'ru').format(booking.bookingDate)} • ${booking.startTime}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text('${booking.serviceName ?? ''} — $statusLabel',
                    style: const TextStyle(color: Colors.white60, fontSize: 13)),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}
