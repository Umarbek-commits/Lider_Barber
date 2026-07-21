import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lider_barber/features/booking/booking_logic.dart';

void main() {
  final day = DateTime(2026, 7, 22); // a Wednesday
  List<int> hoursOf(List<DateTime> slots) => slots.map((s) => s.hour).toList();
  String hhmm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  group('generateAvailableSlots', () {
    test('hourly grid, 1h service, skips break and a booked slot', () {
      final slots = generateAvailableSlots(
        day: day,
        opening: const TimeOfDay(hour: 10, minute: 0),
        closing: const TimeOfDay(hour: 20, minute: 0),
        serviceDuration: const Duration(hours: 1),
        step: const Duration(hours: 1),
        breakStart: const TimeOfDay(hour: 14, minute: 0),
        breakEnd: const TimeOfDay(hour: 15, minute: 0),
        busy: [
          (start: DateTime(2026, 7, 22, 11), end: DateTime(2026, 7, 22, 12)),
        ],
      );

      // 10..19 minus break-overlapping 14 (13:00 ends at 14:00 → allowed) and 11.
      expect(hoursOf(slots), [10, 12, 13, 15, 16, 17, 18, 19]);
    });

    test('service must fully fit before closing', () {
      final slots = generateAvailableSlots(
        day: day,
        opening: const TimeOfDay(hour: 10, minute: 0),
        closing: const TimeOfDay(hour: 12, minute: 0),
        serviceDuration: const Duration(minutes: 90),
        step: const Duration(minutes: 30),
      );
      // 10:00 (ends 11:30) ok, 10:30 (ends 12:00) ok, 11:00 (ends 12:30) no.
      expect(slots.map(hhmm).toList(), ['10:00', '10:30']);
    });

    test('90-min service is blocked from overlapping the break', () {
      final slots = generateAvailableSlots(
        day: day,
        opening: const TimeOfDay(hour: 13, minute: 0),
        closing: const TimeOfDay(hour: 18, minute: 0),
        serviceDuration: const Duration(minutes: 90),
        step: const Duration(minutes: 30),
        breakStart: const TimeOfDay(hour: 14, minute: 0),
        breakEnd: const TimeOfDay(hour: 15, minute: 0),
      );
      // 13:00 (→14:30) and 13:30 (→15:00) hit the break; first valid is 15:00.
      expect(slots.map(hhmm).first, '15:00');
      expect(slots.map(hhmm).contains('13:00'), isFalse);
    });

    test('busy range of arbitrary length blocks all overlapping starts', () {
      final slots = generateAvailableSlots(
        day: day,
        opening: const TimeOfDay(hour: 10, minute: 0),
        closing: const TimeOfDay(hour: 13, minute: 0),
        serviceDuration: const Duration(minutes: 30),
        step: const Duration(minutes: 30),
        busy: [
          (start: DateTime(2026, 7, 22, 11), end: DateTime(2026, 7, 22, 12, 30)),
        ],
      );
      expect(slots.map(hhmm).toList(), ['10:00', '10:30', '12:30']);
    });

    test('past slots are hidden when the day is today', () {
      final now = DateTime(2026, 7, 22, 11, 15);
      final slots = generateAvailableSlots(
        day: day,
        opening: const TimeOfDay(hour: 10, minute: 0),
        closing: const TimeOfDay(hour: 14, minute: 0),
        serviceDuration: const Duration(minutes: 30),
        step: const Duration(minutes: 30),
        now: now,
      );
      // 10:00, 10:30, 11:00 are past (<= now); first offered is 11:30.
      expect(slots.map(hhmm).first, '11:30');
    });

    test('empty when closing precedes opening', () {
      final slots = generateAvailableSlots(
        day: day,
        opening: const TimeOfDay(hour: 20, minute: 0),
        closing: const TimeOfDay(hour: 10, minute: 0),
        serviceDuration: const Duration(hours: 1),
      );
      expect(slots, isEmpty);
    });
  });
}
