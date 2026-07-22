import 'booking_status.dart';

/// A single appointment. Times are stored as Postgres `date` + `time`.
class Booking {
  const Booking({
    required this.id,
    required this.clientId,
    required this.serviceId,
    required this.bookingDate,
    required this.startTime,
    required this.endTime,
    required this.status,
    this.comment,
    this.createdAt,
    this.clientName,
    this.clientPhone,
    this.serviceName,
    this.servicePriceSom,
    this.acceptedBy,
    this.acceptedByName,
    this.acceptedAt,
  });

  final String id;
  final String clientId;
  final String serviceId;

  /// Date only (year/month/day meaningful; time part is zero).
  final DateTime bookingDate;

  /// "HH:mm" wall-clock start/end.
  final String startTime;
  final String endTime;

  final BookingStatus status;
  final String? comment;
  final DateTime? createdAt;

  // Denormalized fields when joined for display.
  final String? clientName;
  final String? clientPhone;
  final String? serviceName;
  final int? servicePriceSom;

  /// The barber who accepted/served this booking (id + resolved name).
  final String? acceptedBy;
  final String? acceptedByName;
  final DateTime? acceptedAt;

  factory Booking.fromMap(Map<String, dynamic> map) {
    final client = map['clients'] as Map<String, dynamic>?;
    final service = map['services'] as Map<String, dynamic>?;
    return Booking(
      id: map['id'] as String,
      clientId: map['client_id'] as String,
      serviceId: map['service_id'] as String,
      bookingDate: DateTime.parse(map['booking_date'] as String),
      startTime: _hhmm(map['start_time'] as String),
      endTime: _hhmm(map['end_time'] as String),
      status: BookingStatus.fromDb(map['status'] as String),
      comment: map['comment'] as String?,
      createdAt: map['created_at'] == null
          ? null
          : DateTime.parse(map['created_at'] as String),
      clientName: client?['name'] as String?,
      clientPhone: client?['phone'] as String?,
      serviceName: service?['name'] as String?,
      servicePriceSom: (service?['price_som'] as num?)?.toInt(),
      acceptedBy: map['accepted_by'] as String?,
      acceptedByName: map['accepted_by_name'] as String?,
      acceptedAt: map['accepted_at'] == null
          ? null
          : DateTime.parse(map['accepted_at'] as String),
    );
  }

  /// Postgres `time` may arrive as "HH:mm:ss"; keep "HH:mm".
  static String _hhmm(String raw) {
    final parts = raw.split(':');
    if (parts.length < 2) return raw;
    return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
  }
}
