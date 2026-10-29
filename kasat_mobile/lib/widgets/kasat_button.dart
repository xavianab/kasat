import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/kasat_theme.dart';

enum KButtonKind {
  /// Blush fill. One per screen.
  primary,

  /// Terracotta outline for the secondary path.
  secondary,

  /// Quiet bordered button.
  soft,

  /// Text-only.
  ghost,
}

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
    this.maxLines = 1,
  });

  final String label;
  final VoidCallback? onPressed;
  final KButtonKind kind;
  final IconData? icon;
  final bool busy;
  final bool expand;
  final bool compact;
  final int maxLines;

  bool get _enabled => onPressed != null && !busy;

  @override
  Widget build(BuildContext context) {
    // Disabled buttons get a flat tint of their own rather than a faded copy
    // of the enabled state: the intake form's primary action spends most of
    // its life disabled, and a washed-out blush fill still reads as "go".
    final (bg, fg, border) = _enabled
        ? switch (kind) {
            KButtonKind.primary => (KC.primary, Colors.white, KC.primary),
            KButtonKind.secondary => (Colors.white, KC.secondary, KC.secondary),
            KButtonKind.soft => (KC.surface, KC.text, KC.borderStrong),
            KButtonKind.ghost => (Colors.transparent, KC.muted, Colors.transparent),
          }
        : (KC.surfaceAlt, KC.faint, KC.border);

    return Material(
      color: bg,
      borderRadius: KRadius.rMd,
      child: InkWell(
        borderRadius: KRadius.rMd,
        onTap: _enabled
            ? () {
                HapticFeedback.selectionClick();
                onPressed!();
              }
            : null,
        child: Container(
          width: expand ? double.infinity : null,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? KSpace.sm : KSpace.xl,
            vertical: compact ? 10 : 15,
          ),
          decoration: BoxDecoration(
            border: Border.all(color: border),
            borderRadius: KRadius.rMd,
          ),
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (busy)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                )
              else if (icon != null)
                Icon(icon, size: compact ? 16 : 17, color: fg),
              if (busy || icon != null) SizedBox(width: compact ? 6 : KSpace.sm),
              Flexible(
                child: Text(
                  label,
                  maxLines: maxLines,
                  overflow: TextOverflow.ellipsis,
                  style: KType.sans(
                    size: compact ? 13 : 15,
                    weight: FontWeight.w600,
                    color: fg,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
