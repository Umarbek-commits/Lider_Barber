import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Read-only 5-star display.
class Stars extends StatelessWidget {
  const Stars({super.key, required this.rating, this.size = 16});
  final int rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (i) => Icon(
          i < rating ? Icons.star_rounded : Icons.star_border_rounded,
          size: size,
          color: AppColors.gold,
        ),
      ),
    );
  }
}

/// Interactive 5-star picker.
class StarPicker extends StatelessWidget {
  const StarPicker({super.key, required this.value, required this.onChanged, this.size = 36});
  final int value;
  final ValueChanged<int> onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        5,
        (i) => IconButton(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          constraints: const BoxConstraints(),
          onPressed: () => onChanged(i + 1),
          icon: Icon(
            i < value ? Icons.star_rounded : Icons.star_border_rounded,
            size: size,
            color: AppColors.gold,
          ),
        ),
      ),
    );
  }
}
