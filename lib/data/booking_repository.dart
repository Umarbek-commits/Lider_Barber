import '../core/supabase_client.dart';
import '../features/booking/booking_logic.dart';

/// Result of attempting to create a booking.
enum BookingOutcome { success, slotTaken, blacklisted, notConfigured, error }

abstract class BookingRepository {
  /// Busy [start,end) ranges for [date] (no client PII), to subtract from slots.
  Future<List<BusyRange>> busyRanges(DateTime date);

  Future<BookingOutcome> createBooking({
    required String serviceId,
    required DateTime date,
    required DateTime start,
    required String name,
    required String phone,
    String? comment,
    String? promoCode,
  });
}

/// Offline fallback — nothing is busy, and booking is disabled.
class SeedBookingRepository implements BookingRepository {
  const SeedBookingRepository();

  @override
  Future<List<BusyRange>> busyRanges(DateTime date) async => const [];

  @override
  Future<BookingOutcome> createBooking({
    required String serviceId,
    required DateTime date,
    required DateTime start,
    required String name,
    required String phone,
    String? comment,
    String? promoCode,
  }) async =>
      BookingOutcome.notConfigured;
}

/// Live implementation calling the public RPCs.
class SupabaseBookingRepository implements BookingRepository {
  const SupabaseBookingRepository();

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  static String _time(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Future<List<BusyRange>> busyRanges(DateTime date) async {
    final rows = await supabase
        .rpc('get_busy_ranges', params: {'p_date': _date(date)}) as List;
    return rows.map<BusyRange>((r) {
      final m = r as Map<String, dynamic>;
      return (
        start: _combine(date, m['start_time'] as String),
        end: _combine(date, m['end_time'] as String),
      );
    }).toList();
  }

  @override
  Future<BookingOutcome> createBooking({
    required String serviceId,
    required DateTime date,
    required DateTime start,
    required String name,
    required String phone,
    String? comment,
    String? promoCode,
  }) async {
    try {
      await supabase.rpc('create_booking', params: {
        'p_service_id': serviceId,
        'p_date': _date(date),
        'p_start': _time(start),
        'p_name': name,
        'p_phone': phone,
        'p_comment': comment,
        'p_promo': promoCode,
      });
      return BookingOutcome.success;
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('slot_taken')) return BookingOutcome.slotTaken;
      if (msg.contains('blacklisted')) return BookingOutcome.blacklisted;
      return BookingOutcome.error;
    }
  }

  static DateTime _combine(DateTime date, String hhmmss) {
    final p = hhmmss.split(':');
    return DateTime(date.year, date.month, date.day,
        int.parse(p[0]), p.length > 1 ? int.parse(p[1]) : 0);
  }
}
