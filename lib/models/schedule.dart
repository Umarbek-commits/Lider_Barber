import 'package:flutter/material.dart';

/// Weekly working hours for a given weekday.
///
/// [weekday] follows Dart's `DateTime.weekday`: Monday = 1 … Sunday = 7.
class Schedule {
  const Schedule({
    required this.id,
    required this.weekday,
    required this.isDayOff,
    this.startTime,
    this.endTime,
    this.breakStart,
    this.breakEnd,
  });

  final String id;
  final int weekday;
  final bool isDayOff;

  /// "HH:mm" or null when it's a day off.
  final String? startTime;
  final String? endTime;
  final String? breakStart;
  final String? breakEnd;

  TimeOfDay? get openingTime => _parse(startTime);
  TimeOfDay? get closingTime => _parse(endTime);
  TimeOfDay? get breakStartTime => _parse(breakStart);
  TimeOfDay? get breakEndTime => _parse(breakEnd);

  factory Schedule.fromMap(Map<String, dynamic> map) {
    return Schedule(
      id: map['id'] as String,
      weekday: (map['weekday'] as num).toInt(),
      isDayOff: (map['is_day_off'] as bool?) ?? false,
      startTime: _hhmm(map['start_time'] as String?),
      endTime: _hhmm(map['end_time'] as String?),
      breakStart: _hhmm(map['break_start'] as String?),
      breakEnd: _hhmm(map['break_end'] as String?),
    );
  }

  static String? _hhmm(String? raw) {
    if (raw == null) return null;
    final parts = raw.split(':');
    if (parts.length < 2) return raw;
    return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
  }

  static TimeOfDay? _parse(String? value) {
    if (value == null) return null;
    final parts = value.split(':');
    if (parts.length < 2) return null;
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }
}
