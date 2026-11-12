import 'package:flutter/material.dart';

/// ডেটা আসার সময় ঘুরন্ত চিহ্নের বদলে কার্ডের ধূসর কাঠামো (skeleton) দেখায়।
/// হালকা ঝিকিমিকি (shimmer) অ্যানিমেশন থাকে, তাই অ্যাপ দ্রুত মনে হয়।
class SkeletonShimmer extends StatefulWidget {
  final Widget child;
  const SkeletonShimmer({super.key, required this.child});

  @override
  State<SkeletonShimmer> createState() => _SkeletonShimmerState();
}

class _SkeletonShimmerState extends State<SkeletonShimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = dark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06);
    final hi = dark ? Colors.white.withValues(alpha: 0.14) : Colors.black.withValues(alpha: 0.02);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = _c.value * 3 - 1; // -1 → 2
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (rect) => LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [base, hi, base],
            stops: [(t - 0.3).clamp(0.0, 1.0), t.clamp(0.0, 1.0), (t + 0.3).clamp(0.0, 1.0)],
          ).createShader(rect),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;
  const SkeletonBox({super.key, this.width, this.height = 12, this.radius = 8});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: dark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// কার্ডের তালিকার মতো দেখতে skeleton
class SkeletonCardList extends StatelessWidget {
  final int count;
  final EdgeInsetsGeometry padding;
  final bool shrinkWrap;
  final double cardHeight;
  const SkeletonCardList({
    super.key,
    this.count = 4,
    this.padding = const EdgeInsets.all(16),
    this.shrinkWrap = false,
    this.cardHeight = 92,
  });

  @override
  Widget build(BuildContext context) {
    final card = Theme.of(context).cardColor;
    final list = ListView.builder(
      padding: padding,
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      itemCount: count,
      itemBuilder: (context, i) => Container(
        height: cardHeight,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(20)),
        child: Row(
          children: [
            const SkeletonBox(width: 44, height: 44, radius: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FractionallySizedBox(widthFactor: i.isEven ? 0.7 : 0.55, child: const SkeletonBox(height: 14)),
                  const SizedBox(height: 10),
                  FractionallySizedBox(widthFactor: i.isEven ? 0.45 : 0.6, child: const SkeletonBox(height: 10)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    return SkeletonShimmer(child: list);
  }
}
