import 'package:flutter/material.dart';

/// A busy interval [start, end) that a new booking must not overlap.
typedef BusyRange = ({DateTime start, DateTime end});

/// Pure slot generator — the professional "auto slots" feature: the barber
/// never creates times by hand, they fall out of working hours + duration.
///
/// A candidate start time is offered only when ALL hold:
///  * the whole service [start, start+duration) fits within [opening, closing);
///  * it does not overlap the lunch break;
///  * it does not overlap any [busy] range;
///  * if [day] is today, the start is not in the past (relative to [now]).
///
/// Slots are generated on a grid of [step] (default 30 min) starting at
/// [opening]. Times are wall-clock `DateTime`s on [day].
List<DateTime> generateAvailableSlots({
  required DateTime day,
  required TimeOfDay opening,
  required TimeOfDay closing,
  required Duration serviceDuration,
  List<BusyRange> busy = const [],
  TimeOfDay? breakStart,
  TimeOfDay? breakEnd,
  Duration step = const Duration(minutes: 30),
  DateTime? now,
}) {
  final slots = <DateTime>[];
  final openMin = opening.hour * 60 + opening.minute;
  final closeMin = closing.hour * 60 + closing.minute;
  final stepMin = step.inMinutes;
  final durMin = serviceDuration.inMinutes;
  if (stepMin <= 0 || durMin <= 0 || closeMin <= openMin) return slots;

  final breakStartMin =
      breakStart == null ? null : breakStart.hour * 60 + breakStart.minute;
  final breakEndMin =
      breakEnd == null ? null : breakEnd.hour * 60 + breakEnd.minute;

  DateTime at(int minutesFromMidnight) => DateTime(
        day.year,
        day.month,
        day.day,
        minutesFromMidnight ~/ 60,
        minutesFromMidnight % 60,
      );

  bool overlaps(
          DateTime aStart, DateTime aEnd, DateTime bStart, DateTime bEnd) =>
      aStart.isBefore(bEnd) && aEnd.isAfter(bStart);

  for (var startMin = openMin;
      startMin + durMin <= closeMin;
      startMin += stepMin) {
    final slotStart = at(startMin);
    final slotEnd = at(startMin + durMin);

    // Break overlap.
    if (breakStartMin != null && breakEndMin != null) {
      if (overlaps(slotStart, slotEnd, at(breakStartMin), at(breakEndMin))) {
        continue;
      }
    }

    // Past time on the current day.
    if (now != null &&
        day.year == now.year &&
        day.month == now.month &&
        day.day == now.day &&
        !slotStart.isAfter(now)) {
      continue;
    }

    // Existing bookings.
    final busyClash =
        busy.any((b) => overlaps(slotStart, slotEnd, b.start, b.end));
    if (busyClash) continue;

    slots.add(slotStart);
  }

  return slots;
}
