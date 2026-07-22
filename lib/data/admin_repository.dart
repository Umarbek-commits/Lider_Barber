import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

import '../core/env.dart';
import '../core/supabase_client.dart';
import '../models/app_user.dart';
import '../models/booking.dart';
import '../models/booking_status.dart';
import '../models/client.dart';
import '../models/schedule.dart';
import '../models/schedule_exception.dart';

/// Aggregate numbers for the dashboard over a date range.
class DashboardStats {
  const DashboardStats({required this.clients, required this.revenue});
  final int clients;
  final int revenue;
  static const empty = DashboardStats(clients: 0, revenue: 0);
}

/// Admin-only reads/writes. Every call requires an authenticated admin; RLS on
/// the tables enforces this server-side regardless of the UI.
class AdminRepository {
  const AdminRepository();

  static String date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  static String _time(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  // --- Schedule (day view) ---------------------------------------------------

  /// Active bookings for a day (pending/confirmed). Completed and cancelled
  /// bookings leave the schedule and live on in the client's history.
  Future<List<Booking>> bookingsForDate(DateTime day) async {
    final rows = await supabase
        .from('bookings')
        .select('*, clients(name,phone), services(name,price_som)')
        .eq('booking_date', date(day))
        .inFilter('status', ['pending', 'confirmed'])
        .order('start_time');
    return rows.map((r) => Booking.fromMap(r)).toList();
  }

  /// Change a booking's status. Goes through the RPC so the acting barber is
  /// recorded as who accepted/served the client.
  Future<void> setStatus(String bookingId, BookingStatus status) async {
    await supabase.rpc('staff_set_status',
        params: {'p_id': bookingId, 'p_status': status.dbValue});
  }

  // --- Masters (barbers) -----------------------------------------------------

  /// All staff (admin + barbers), used to resolve "who accepted" names.
  Future<List<AppUser>> staff() async {
    final rows = await supabase
        .from('users')
        .select()
        .inFilter('role', ['admin', 'barber']).order('name');
    return rows.map((r) => AppUser.fromMap(r)).toList();
  }

  Future<List<AppUser>> barbers() async {
    final rows =
        await supabase.from('users').select().eq('role', 'barber').order('name');
    return rows.map((r) => AppUser.fromMap(r)).toList();
  }

  /// Create a barber account (admin only). A throwaway client performs the
  /// signup so the admin's own session is not replaced; then the account is
  /// promoted to 'barber'. Requires "Confirm email" disabled in Supabase.
  Future<void> createBarber({
    required String name,
    required String email,
    required String password,
  }) async {
    final temp = SupabaseClient(Env.supabaseUrl, Env.supabaseAnonKey);
    try {
      await temp.auth.signUp(
        email: email.trim(),
        password: password,
        data: {'full_name': name.trim()},
      );
    } finally {
      await temp.dispose();
    }
    await supabase
        .rpc('set_barber', params: {'p_email': email.trim(), 'p_name': name.trim()});
  }

  Future<void> removeBarber(String userId) async {
    await supabase.rpc('remove_barber', params: {'p_user_id': userId});
  }

  /// Move a booking to a new start, preserving its duration.
  Future<void> moveBooking({
    required Booking booking,
    required DateTime newDate,
    required DateTime newStart,
  }) async {
    final duration = _minutes(booking.endTime) - _minutes(booking.startTime);
    final newEnd = newStart.add(Duration(minutes: duration));
    await supabase.from('bookings').update({
      'booking_date': date(newDate),
      'start_time': _time(newStart),
      'end_time': _time(newEnd),
    }).eq('id', booking.id);
  }

  /// Create a booking from the admin side (reuses the guarded RPC, so client
  /// upsert, blacklist and the anti-overlap rule all apply).
  Future<void> createBooking({
    required String serviceId,
    required DateTime day,
    required DateTime start,
    required String name,
    required String phone,
    String? comment,
  }) async {
    await supabase.rpc('create_booking', params: {
      'p_service_id': serviceId,
      'p_date': date(day),
      'p_start': _time(start),
      'p_name': name,
      'p_phone': phone,
      'p_comment': comment,
    });
  }

  // --- Dashboard -------------------------------------------------------------

  /// Stats over [from]..[to] inclusive. Revenue counts only completed visits.
  Future<DashboardStats> stats(DateTime from, DateTime to) async {
    final rows = await supabase
        .from('bookings')
        .select('status, services(price_som)')
        .gte('booking_date', date(from))
        .lte('booking_date', date(to))
        .neq('status', 'cancelled')
        .neq('status', 'no_show');
    var clients = 0;
    var revenue = 0;
    for (final r in rows) {
      clients++;
      if (r['status'] == 'completed') {
        final price = (r['services'] as Map?)?['price_som'];
        if (price is num) revenue += price.toInt();
      }
    }
    return DashboardStats(clients: clients, revenue: revenue);
  }

  // --- Clients ---------------------------------------------------------------

  Future<List<Client>> clients() async {
    final rows = await supabase
        .from('clients')
        .select()
        .order('last_visit', ascending: false, nullsFirst: false)
        .order('name');
    return rows.map((r) => Client.fromMap(r)).toList();
  }

  Future<List<Booking>> clientBookings(String clientId) async {
    final rows = await supabase
        .from('bookings')
        .select('*, services(name,price_som)')
        .eq('client_id', clientId)
        .order('booking_date', ascending: false)
        .order('start_time', ascending: false);
    return rows.map((r) => Booking.fromMap(r)).toList();
  }

  Future<void> setBlacklist(String clientId, bool blacklisted, String? reason) async {
    await supabase.from('clients').update({
      'is_blacklisted': blacklisted,
      'blacklist_reason': blacklisted ? reason : null,
    }).eq('id', clientId);
  }

  // --- Settings: weekly schedule + exceptions --------------------------------

  Future<List<Schedule>> schedules() async {
    final rows =
        await supabase.from('schedules').select().order('weekday');
    return rows.map((r) => Schedule.fromMap(r)).toList();
  }

  Future<void> upsertSchedule({
    required int weekday,
    required bool isDayOff,
    String? start,
    String? end,
    String? breakStart,
    String? breakEnd,
  }) async {
    await supabase.from('schedules').upsert({
      'weekday': weekday,
      'is_day_off': isDayOff,
      'start_time': isDayOff ? null : start,
      'end_time': isDayOff ? null : end,
      'break_start': isDayOff ? null : breakStart,
      'break_end': isDayOff ? null : breakEnd,
    }, onConflict: 'weekday');
  }

  Future<List<ScheduleException>> exceptions() async {
    final rows = await supabase
        .from('schedule_exceptions')
        .select()
        .gte('date', date(DateTime.now()))
        .order('date');
    return rows.map((r) => ScheduleException.fromMap(r)).toList();
  }

  Future<void> addException({
    required DateTime day,
    required ScheduleExceptionType type,
    String? start,
    String? end,
  }) async {
    await supabase.from('schedule_exceptions').upsert({
      'date': date(day),
      'type': type.dbValue,
      'start_time': type == ScheduleExceptionType.dayOff ? null : start,
      'end_time': type == ScheduleExceptionType.dayOff ? null : end,
    }, onConflict: 'date');
  }

  Future<void> deleteException(String id) async {
    await supabase.from('schedule_exceptions').delete().eq('id', id);
  }

  static int _minutes(String hhmm) {
    final p = hhmm.split(':');
    return int.parse(p[0]) * 60 + int.parse(p[1]);
  }
}
