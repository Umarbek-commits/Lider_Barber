import 'package:flutter/material.dart';

/// A compact button that opens a time picker and reports the picked "HH:mm".
class TimeButton extends StatelessWidget {
  const TimeButton({super.key, required this.label, required this.onPick});

  final String label;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 38),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: () async {
        final parts = label.split(':');
        final picked = await showTimePicker(
          context: context,
          initialTime: TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])),
        );
        if (picked != null) {
          onPick(
              '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}');
        }
      },
      child: Text(label),
    );
  }
}
