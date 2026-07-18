import 'package:flutter/material.dart';
import 'package:syu_sri_lanka/core/theme/syu_theme.dart';

/// Brand mark using the full logo asset as-is (no image editing).
class SyuBrandMark extends StatelessWidget {
  const SyuBrandMark({
    super.key,
    this.height = 72,
    this.showWordmark = false,
  });

  final double height;
  final bool showWordmark;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/brand/syu_logo.png',
          height: height,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
        if (showWordmark) ...[
          const SizedBox(height: 14),
          Text(
            'SYU',
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  color: SyuColors.crimson,
                  height: 0.9,
                ),
          ),
          Text(
            'SRI LANKA',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: SyuColors.steel,
                  letterSpacing: 4,
                ),
          ),
        ],
      ],
    );
  }
}

class SyuGradientBackground extends StatelessWidget {
  const SyuGradientBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFFFFFF),
            Color(0xFFFFF8F7),
            Color(0xFFF7F7F7),
          ],
          stops: [0, 0.55, 1],
        ),
      ),
      child: child,
    );
  }
}
