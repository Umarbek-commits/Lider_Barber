import '../core/supabase_client.dart';
import '../models/booking.dart';

/// Reads/writes for the signed-in client's own bookings. RLS restricts every
/// query to rows where user_id = auth.uid().
class ClientRepository {
  const ClientRepository();

  Future<List<Booking>> myBookings() async {
    final uid = maybeCurrentUser?.id;
    if (uid == null) return const [];
    final rows = await supabase
        .from('bookings')
        .select('*, services(name,price_som)')
        .eq('user_id', uid)
        .order('booking_date', ascending: false)
        .order('start_time', ascending: false);
    return rows.map((r) => Booking.fromMap(r)).toList();
  }

  Future<void> cancel(String bookingId) async {
    await supabase.rpc('cancel_booking', params: {'p_id': bookingId});
  }

  Future<void> leaveReview({
    required String bookingId,
    required int rating,
    String? review,
  }) async {
    await supabase.rpc('leave_review', params: {
      'p_booking_id': bookingId,
      'p_rating': rating,
      'p_review': review,
    });
  }
}
