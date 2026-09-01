import 'package:flutter/material.dart';

import '../theme/kasat_theme.dart';

/// Small rounded chip. Replaces the old monospace metadata badge: same job,
/// but sentence case, soft tint, and no border unless it needs one.
class SoftBadge extends StatelessWidget {
  const SoftBadge(
    this.text, {
    super.key,
    this.color = KC.muted,
    this.background,
    this.icon,
    this.size = 12,
    this.dense = false,
  });

  final String text;
  final Color color;
  final Color? background;
  final IconData? icon;
  final double size;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 10,
        vertical: dense ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: background ?? color.withValues(alpha: 0.10),
        borderRadius: KRadius.rPill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: size + 2, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            text,
            style: KType.sans(size: size, weight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}

/// Slow, soft pulse. Used to mark a live view without the blinking-terminal
/// feel of the previous indicator.
class PulseDot extends StatefulWidget {
  const PulseDot({super.key, this.color = KC.primary, this.size = 8});

  final Color color;
  final double size;

  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.4, end: 1).animate(
        CurvedAnimation(parent: _c, curve: Curves.easeInOut),
      ),
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}

/// The tracking code, wherever it appears at small size.
class CodeChip extends StatelessWidget {
  const CodeChip(this.code, {super.key, this.color = KC.secondary, this.size = 13});

  final String code;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: KRadius.rSm,
      ),
      child: Text(code, style: KType.code(size: size, color: color, tracking: 1.2)),
    );
  }
}
