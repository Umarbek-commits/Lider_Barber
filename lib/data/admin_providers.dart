import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_user.dart';
import '../models/booking.dart';
import '../models/client.dart';
import '../models/news_item.dart';
import '../models/schedule.dart';
import '../models/schedule_exception.dart';
import 'admin_repository.dart';

final adminRepositoryProvider = Provider<AdminRepository>((_) => const AdminRepository());

/// Bookings for a given day (admin schedule view).
final adminBookingsProvider =
    FutureProvider.family<List<Booking>, DateTime>((ref, day) {
  return ref.watch(adminRepositoryProvider).bookingsForDate(day);
});

typedef DateRange = ({DateTime from, DateTime to});

final dashboardStatsProvider =
    FutureProvider.family<DashboardStats, DateRange>((ref, range) {
  return ref.watch(adminRepositoryProvider).stats(range.from, range.to);
});

final adminClientsProvider = FutureProvider<List<Client>>((ref) {
  return ref.watch(adminRepositoryProvider).clients();
});

// autoDispose so the client card re-fetches fresh history (ratings, statuses)
// every time it's opened instead of showing a stale cached value.
final clientBookingsProvider =
    FutureProvider.autoDispose.family<List<Booking>, String>((ref, clientId) {
  return ref.watch(adminRepositoryProvider).clientBookings(clientId);
});

final adminSchedulesProvider = FutureProvider<List<Schedule>>((ref) {
  return ref.watch(adminRepositoryProvider).schedules();
});

final adminExceptionsProvider = FutureProvider<List<ScheduleException>>((ref) {
  return ref.watch(adminRepositoryProvider).exceptions();
});

final adminBarbersProvider = FutureProvider<List<AppUser>>((ref) {
  return ref.watch(adminRepositoryProvider).barbers();
});

final adminNewsProvider = FutureProvider<List<NewsItem>>((ref) {
  return ref.watch(adminRepositoryProvider).news();
});

final barberRatingsProvider =
    FutureProvider<Map<String, ({double avg, int count})>>((ref) {
  return ref.watch(adminRepositoryProvider).barberRatings();
});

/// Map of staff id → display name, to resolve "accepted by" on bookings.
final staffNamesProvider = FutureProvider<Map<String, String>>((ref) async {
  final staff = await ref.watch(adminRepositoryProvider).staff();
  return {for (final u in staff) u.id: (u.name ?? u.phone)};
});
