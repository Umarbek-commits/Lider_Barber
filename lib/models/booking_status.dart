/// Lifecycle of a booking. Values match the `status` column in Postgres.
enum BookingStatus {
  pending,
  confirmed,
  completed,
  cancelled,
  noShow;

  String get dbValue => switch (this) {
        BookingStatus.pending => 'pending',
        BookingStatus.confirmed => 'confirmed',
        BookingStatus.completed => 'completed',
        BookingStatus.cancelled => 'cancelled',
        BookingStatus.noShow => 'no_show',
      };

  String get label => switch (this) {
        BookingStatus.pending => 'Ожидает',
        BookingStatus.confirmed => 'Подтверждена',
        BookingStatus.completed => 'Выполнена',
        BookingStatus.cancelled => 'Отменена',
        BookingStatus.noShow => 'Не пришёл',
      };

  static BookingStatus fromDb(String value) => switch (value) {
        'pending' => BookingStatus.pending,
        'confirmed' => BookingStatus.confirmed,
        'completed' => BookingStatus.completed,
        'cancelled' => BookingStatus.cancelled,
        'no_show' => BookingStatus.noShow,
        _ => BookingStatus.pending,
      };
}
