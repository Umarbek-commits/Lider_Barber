import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/env.dart';
import '../core/supabase_client.dart';
import '../features/booking/booking_logic.dart';
import '../models/app_user.dart';
import '../models/booking.dart';
import '../models/news_item.dart';
import '../models/promo_code.dart';
import '../models/service.dart';
import 'booking_repository.dart';
import 'catalog_repository.dart';
import 'client_repository.dart';

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

/// The signed-in client's bonus balance + penalties (сом).
final myBonusesProvider = FutureProvider<({int bonus, int penalty})>((ref) async {
  ref.watch(authStateProvider);
  if (!Env.hasSupabase || maybeCurrentUser == null) return (bonus: 0, penalty: 0);
  final rows = await supabase.rpc('my_bonuses') as List;
  if (rows.isEmpty) return (bonus: 0, penalty: 0);
  final r = rows.first as Map<String, dynamic>;
  return (
    bonus: (r['bonus_som'] as num?)?.toInt() ?? 0,
    penalty: (r['penalty_som'] as num?)?.toInt() ?? 0,
  );
});

/// Cashback percent (public app setting), for the client bonuses page/booking.
final publicCashbackPctProvider = FutureProvider<int>((ref) async {
  if (!Env.hasSupabase) return 0;
  final row =
      await supabase.from('app_settings').select('cashback_pct').eq('id', 1).maybeSingle();
  return (row?['cashback_pct'] as num?)?.toInt() ?? 0;
});

/// Active promo codes clients can see/use.
final activePromosProvider = FutureProvider<List<PromoCode>>((ref) async {
  if (!Env.hasSupabase) return const [];
  final rows = await supabase
      .from('promo_codes')
      .select()
      .eq('is_active', true)
      .order('discount_som', ascending: false);
  return rows.map((r) => PromoCode.fromMap(r)).toList();
});

/// Active announcements shown to clients on the home screen.
final newsProvider = FutureProvider<List<NewsItem>>((ref) async {
  if (!Env.hasSupabase) return const [];
  final rows = await supabase
      .from('news')
      .select()
      .eq('is_active', true)
      .order('created_at', ascending: false);
  return rows.map((r) => NewsItem.fromMap(r)).toList();
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
  try {
    return supabase.auth.onAuthStateChange;
  } catch (_) {
    return const Stream.empty(); // Supabase not initialized (e.g. in tests)
  }
});

final clientRepositoryProvider = Provider<ClientRepository>((_) => const ClientRepository());

/// The signed-in client's own bookings (newest first).
final myBookingsProvider = FutureProvider<List<Booking>>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(clientRepositoryProvider).myBookings();
});

/// The current authenticated profile (with role), or null when signed out.
final currentUserProvider = FutureProvider<AppUser?>((ref) async {
  if (!Env.hasSupabase) return null;
  ref.watch(authStateProvider); // re-run when auth changes
  final uid = maybeCurrentUser?.id;
  if (uid == null) return null;
  final row =
      await supabase.from('users').select().eq('id', uid).maybeSingle();
  return row == null ? null : AppUser.fromMap(row);
});
