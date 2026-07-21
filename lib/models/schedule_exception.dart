import 'package:flutter/material.dart';

enum ScheduleExceptionType {
  dayOff,
  customHours;

  String get dbValue =>
      this == ScheduleExceptionType.dayOff ? 'day_off' : 'custom_hours';

  static ScheduleExceptionType fromDb(String value) =>
      value == 'day_off'
          ? ScheduleExceptionType.dayOff
          : ScheduleExceptionType.customHours;
}

/// A one-off override for a specific date (holiday or shortened day).
class ScheduleException {
  const ScheduleException({
    required this.id,
    required this.date,
    required this.type,
    this.startTime,
    this.endTime,
  });

  final String id;
  final DateTime date;
  final ScheduleExceptionType type;
  final String? startTime;
  final String? endTime;

  TimeOfDay? get openingTime => _parse(startTime);
  TimeOfDay? get closingTime => _parse(endTime);

  factory ScheduleException.fromMap(Map<String, dynamic> map) {
    return ScheduleException(
      id: map['id'] as String,
      date: DateTime.parse(map['date'] as String),
      type: ScheduleExceptionType.fromDb(map['type'] as String),
      startTime: _hhmm(map['start_time'] as String?),
      endTime: _hhmm(map['end_time'] as String?),
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
