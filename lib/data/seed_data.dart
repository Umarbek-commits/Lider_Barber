import 'package:flutter/material.dart';

import '../models/schedule.dart';
import '../models/service.dart';

/// Fallback catalogue used when Supabase keys are not configured, so the UI is
/// fully browsable as a static prototype. Mirrors `supabase/migrations/0004_seed.sql`.
class SeedData {
  const SeedData._();

  static const List<Service> services = [
    Service(id: 'seed-1', name: 'Мужская стрижка', priceSom: 500, durationMin: 60, sortOrder: 1),
    Service(id: 'seed-2', name: 'Борода', priceSom: 300, durationMin: 45, sortOrder: 2),
    Service(id: 'seed-3', name: 'Комплекс', priceSom: 700, durationMin: 90, sortOrder: 3),
    Service(id: 'seed-4', name: 'Детская стрижка', priceSom: 400, durationMin: 60, sortOrder: 4),
  ];

  /// weekday 1..7 (Mon..Sun). Sunday is a day off.
  static Schedule scheduleFor(int weekday) {
    if (weekday == 7) {
      return Schedule(id: 'seed-wd-7', weekday: 7, isDayOff: true);
    }
    final closing = weekday == 6 ? '18:00' : '20:00';
    return Schedule(
      id: 'seed-wd-$weekday',
      weekday: weekday,
      isDayOff: false,
      startTime: '10:00',
      endTime: closing,
      breakStart: weekday == 6 ? null : '14:00',
      breakEnd: weekday == 6 ? null : '15:00',
    );
  }

  static const TimeOfDay defaultStep = TimeOfDay(hour: 0, minute: 30);
}
