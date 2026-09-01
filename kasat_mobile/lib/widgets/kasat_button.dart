import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/kasat_theme.dart';

enum KButtonKind { primary, outline, ghost, danger }

/// Squared-off action button. Labels are uppercase monospace so a button is
/// never mistaken for prose.
class KButton extends StatelessWidget {
  const KButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.kind = KButtonKind.primary,
    this.icon,
    this.busy = false,
    this.expand = true,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final KButtonKind kind;
  final IconData? icon;
  final bool busy;
  final bool expand;
  final bool compact;

  bool get _enabled => onPressed != null && !busy;

  @override
  Widget build(BuildContext context) {
    // A disabled action gets its own flat treatment rather than a faded copy
    // of the enabled one: a translucent emerald fill still reads as "go", and
    // the primary button on the intake form spends most of its life disabled.
    final (bg, fg, border) = _enabled
        ? switch (kind) {
            KButtonKind.primary => (KC.accent, KC.canvas, KC.accent),
            KButtonKind.outline => (Colors.transparent, KC.text, KC.borderHi),
            KButtonKind.ghost => (Colors.transparent, KC.muted, Colors.transparent),
            KButtonKind.danger => (KC.danger.withValues(alpha: 0.12), KC.danger, KC.danger),
          }
        : (KC.surfaceHi, KC.faint, KC.border);

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: _enabled
            ? () {
                HapticFeedback.selectionClick();
                onPressed!();
              }
            : null,
        child: Container(
          width: expand ? double.infinity : null,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? KSpace.md : KSpace.lg,
            vertical: compact ? KSpace.sm : 13,
          ),
          decoration: BoxDecoration(
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (busy)
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 1.6, color: fg),
                )
              else if (icon != null)
                Icon(icon, size: 14, color: fg),
              if (busy || icon != null) const SizedBox(width: KSpace.sm),
              Text(
                label.toUpperCase(),
                style: KType.mono(
                  size: compact ? 10.5 : 12,
                  weight: FontWeight.w700,
                  color: fg,
                  tracking: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
