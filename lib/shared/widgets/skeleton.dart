import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Animated shimmer wrapper. Put opaque [SkeletonBox]es inside; the moving
/// highlight is painted over them.
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.child});
  final Widget child;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1250))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final base = dark ? const Color(0xFF1B1B1B) : const Color(0xFFE4E4E8);
    final highlight = dark ? const Color(0xFF2C2C2C) : const Color(0xFFF4F4F6);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final v = _c.value * 2 - 0.5; // sweep from off-screen left to right
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [base, highlight, base],
              stops: [
                (v - 0.3).clamp(0.0, 1.0),
                v.clamp(0.0, 1.0),
                (v + 0.3).clamp(0.0, 1.0),
              ],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// One opaque placeholder block (colour is overpainted by [Shimmer]).
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.width, this.height = 16, this.radius = 8});
  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: context.surfaceAlt, // repainted by the shimmer shader
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// A list of card-shaped skeletons — the common "loading rows" placeholder.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.count = 4, this.cardHeight = 64});
  final int count;
  final double cardHeight;

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Column(
        children: List.generate(
          count,
          (_) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SkeletonBox(height: cardHeight, radius: 16, width: double.infinity),
          ),
        ),
      ),
    );
  }
}
