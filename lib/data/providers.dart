import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/env.dart';
import '../core/supabase_client.dart';
import '../features/booking/booking_logic.dart';
import '../models/app_user.dart';
import '../models/service.dart';
import 'booking_repository.dart';
import 'catalog_repository.dart';

/// Whether the app is wired to a live backend.
final backendConfiguredProvider = Provider<bool>((_) => Env.hasSupabase);

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  return Env.hasSupabase
      ? const SupabaseCatalogRepository()
      : const SeedCatalogRepository();
});

final bookingRepositoryProvider = Provider<BookingRepository>((ref) {
  return Env.hasSupabase
      ? const SupabaseBookingRepository()
      : const SeedBookingRepository();
});

final servicesProvider = FutureProvider<List<Service>>((ref) {
  return ref.watch(catalogRepositoryProvider).activeServices();
});

/// Parameters for computing free slots for one service on one day.
typedef SlotQuery = ({String serviceId, int durationMin, DateTime date});

/// Computed free start times for a service+date: working hours (minus break),
/// minus existing bookings, minus past times — all via the pure [generateAvailableSlots].
final availableSlotsProvider =
    FutureProvider.family<List<DateTime>, SlotQuery>((ref, q) async {
  final schedule =
      await ref.watch(catalogRepositoryProvider).scheduleFor(q.date.weekday);
  if (schedule == null ||
      schedule.isDayOff ||
      schedule.openingTime == null ||
      schedule.closingTime == null) {
    return const [];
  }
  final busy = await ref.watch(bookingRepositoryProvider).busyRanges(q.date);
  return generateAvailableSlots(
    day: q.date,
    opening: schedule.openingTime!,
    closing: schedule.closingTime!,
    serviceDuration: Duration(minutes: q.durationMin),
    breakStart: schedule.breakStartTime,
    breakEnd: schedule.breakEndTime,
    busy: busy,
    step: const Duration(minutes: 30),
    now: DateTime.now(),
  );
});

/// True if the barber works on [date] (weekly schedule; exceptions come later).
final worksOnDateProvider =
    FutureProvider.family<bool, DateTime>((ref, date) async {
  final schedule =
      await ref.watch(catalogRepositoryProvider).scheduleFor(date.weekday);
  return schedule != null && !schedule.isDayOff;
});

/// Emits on every auth state change (login / logout / token refresh).
final authStateProvider = StreamProvider<AuthState?>((ref) {
  if (!Env.hasSupabase) return const Stream.empty();
  return supabase.auth.onAuthStateChange;
});

/// The current authenticated profile (with role), or null when signed out.
final currentUserProvider = FutureProvider<AppUser?>((ref) async {
  if (!Env.hasSupabase) return null;
  ref.watch(authStateProvider); // re-run when auth changes
  final uid = supabase.auth.currentUser?.id;
  if (uid == null) return null;
  final row =
      await supabase.from('users').select().eq('id', uid).maybeSingle();
  return row == null ? null : AppUser.fromMap(row);
});
