import 'package:flutter/material.dart';

import '../theme/kasat_theme.dart';

/// A bordered frame with a numbered header strip. Every form section and data
/// block on the client sits inside one of these so the eye can scan the
/// screen by its rules rather than by its whitespace.
class KPanel extends StatelessWidget {
  const KPanel({
    super.key,
    required this.title,
    required this.child,
    this.index,
    this.trailing,
    this.accent = KC.border,
    this.padding = const EdgeInsets.all(KSpace.md),
  });

  final String title;
  final Widget child;

  /// Two-digit step marker, e.g. `01`.
  final String? index;
  final Widget? trailing;
  final Color accent;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: KC.surface,
        border: Border.all(color: accent),
        borderRadius: BorderRadius.circular(6),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(KSpace.md, KSpace.sm, KSpace.sm, KSpace.sm),
            decoration: const BoxDecoration(
              color: KC.surfaceHi,
              border: Border(bottom: BorderSide(color: KC.border)),
            ),
            child: Row(
              children: [
                if (index != null) ...[
                  Text(
                    index!,
                    style: KType.mono(
                      size: 10,
                      weight: FontWeight.w700,
                      color: KC.accent,
                      tracking: 1,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 10,
                    margin: const EdgeInsets.symmetric(horizontal: KSpace.sm),
                    color: KC.borderHi,
                  ),
                ],
                Expanded(
                  child: Text(
                    title.toUpperCase(),
                    style: KType.label(color: KC.text, size: 10),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

/// Hairline separator matched to the panel border.
class KRule extends StatelessWidget {
  const KRule({super.key, this.height = KSpace.md});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: height / 2),
      child: const Divider(height: 1, thickness: 1, color: KC.border),
    );
  }
}

/// `LABEL ......... value` row. Dotted leader keeps dense stacks readable.
class KMetaRow extends StatelessWidget {
  const KMetaRow(this.label, this.value, {super.key, this.valueColor = KC.text, this.valueWidget});

  final String label;
  final String value;
  final Color valueColor;
  final Widget? valueWidget;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: Text(label.toUpperCase(), style: KType.label(size: 9.5)),
          ),
          Expanded(
            child: valueWidget ??
                Text(
                  value,
                  style: KType.mono(size: 11, color: valueColor, weight: FontWeight.w600),
                ),
          ),
        ],
      ),
    );
  }
}
