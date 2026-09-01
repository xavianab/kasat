import 'package:flutter/material.dart';

import '../theme/kasat_theme.dart';

/// The workhorse metadata chip: uppercase monospace on a tinted plate.
class MonoBadge extends StatelessWidget {
  const MonoBadge(
    this.text, {
    super.key,
    this.color = KC.muted,
    this.filled = false,
    this.icon,
    this.size = 10,
    this.dense = false,
  });

  final String text;
  final Color color;
  final bool filled;
  final IconData? icon;
  final double size;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 5 : 7,
        vertical: dense ? 2 : 3.5,
      ),
      decoration: BoxDecoration(
        color: filled ? color.withValues(alpha: 0.14) : Colors.transparent,
        border: Border.all(color: color.withValues(alpha: filled ? 0.35 : 0.5)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: size + 2, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            text.toUpperCase(),
            style: KType.mono(
              size: size,
              weight: FontWeight.w700,
              color: color,
              tracking: 0.9,
            ),
          ),
        ],
      ),
    );
  }
}

/// A small pulsing dot used to mark live/armed states.
class LiveDot extends StatefulWidget {
  const LiveDot({super.key, this.color = KC.accent, this.size = 6});

  final Color color;
  final double size;

  @override
  State<LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<LiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.25, end: 1).animate(_c),
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}
