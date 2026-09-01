import 'package:flutter/material.dart';

import '../theme/kasat_theme.dart';

/// Faint engineering grid behind hero surfaces. Sits at ~3% contrast: it
/// should register as texture, never as content.
class GridBackdrop extends StatelessWidget {
  const GridBackdrop({super.key, this.cell = 22, this.child});

  final double cell;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _GridPainter(cell),
      child: child,
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter(this.cell);

  final double cell;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = KC.borderHi.withValues(alpha: 0.14)
      ..strokeWidth = 0.5;

    for (var x = 0.0; x < size.width; x += cell) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y < size.height; y += cell) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) => oldDelegate.cell != cell;
}
