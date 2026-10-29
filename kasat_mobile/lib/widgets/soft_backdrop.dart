import 'package:flutter/material.dart';

import '../theme/kasat_theme.dart';

/// Warm wash behind hero surfaces. Replaces the old engineering grid — a
/// blueprint texture reads as "tool", which is the opposite of what this
/// interface is trying to feel like.
class SoftBackdrop extends StatelessWidget {
  const SoftBackdrop({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFFFDEFF3), KC.canvas, Color(0xFFFBF1EA)],
          stops: [0, 0.55, 1],
        ),
      ),
      child: child,
    );
  }
}

/// Soft dashed outline for drop targets.
class DashedBorder extends StatelessWidget {
  const DashedBorder({
    super.key,
    required this.child,
    this.color = KC.borderStrong,
    this.radius = KRadius.md,
    this.dash = 7,
    this.gap = 5,
  });

  final Widget child;
  final Color color;
  final double radius;
  final double dash;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedPainter(color: color, radius: radius, dash: dash, gap: gap),
      child: child,
    );
  }
}

class _DashedPainter extends CustomPainter {
  _DashedPainter({
    required this.color,
    required this.radius,
    required this.dash,
    required this.gap,
  });

  final Color color;
  final double radius;
  final double dash;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      );

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = (distance + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedPainter old) => old.color != color;
}
