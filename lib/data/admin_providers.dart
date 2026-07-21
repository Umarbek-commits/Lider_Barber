import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/booking.dart';
import '../models/client.dart';
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

final clientBookingsProvider =
    FutureProvider.family<List<Booking>, String>((ref, clientId) {
  return ref.watch(adminRepositoryProvider).clientBookings(clientId);
});

final adminSchedulesProvider = FutureProvider<List<Schedule>>((ref) {
  return ref.watch(adminRepositoryProvider).schedules();
});

final adminExceptionsProvider = FutureProvider<List<ScheduleException>>((ref) {
  return ref.watch(adminRepositoryProvider).exceptions();
});
