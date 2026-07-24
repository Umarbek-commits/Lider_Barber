/// Fixed pricing rules shared by client and admin.
const int eveningSurchargeSom = 50;
const int lateCancelPenaltySom = 50;

/// Evening surcharge (+50 сом) for bookings that start 20:00–22:59.
/// Accepts an "HH:mm[:ss]" string or a DateTime.
int eveningSurcharge(Object? start) {
  int? hour;
  if (start is String && start.contains(':')) {
    hour = int.tryParse(start.split(':').first);
  } else if (start is DateTime) {
    hour = start.hour;
  }
  if (hour == null) return 0;
  return (hour >= 20 && hour < 23) ? eveningSurchargeSom : 0;
}
