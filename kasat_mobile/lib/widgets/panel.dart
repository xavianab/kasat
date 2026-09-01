import 'package:flutter/material.dart';

import '../theme/kasat_theme.dart';

/// Rounded card with an optional heading row. Everything on a Kasat screen
/// sits inside one of these.
class KPanel extends StatelessWidget {
  const KPanel({
    super.key,
    this.title,
    required this.child,
    this.step,
    this.trailing,
    this.subtitle,
    this.background = KC.surface,
    this.border = KC.border,
    this.padding = const EdgeInsets.all(KSpace.lg),
    this.shadow = true,
  });

  final String? title;
  final Widget child;

  /// Optional step number for the multi-part intake form.
  final int? step;
  final Widget? trailing;
  final String? subtitle;
  final Color background;
  final Color border;
  final EdgeInsets padding;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: border),
        borderRadius: KRadius.rLg,
        boxShadow: shadow ? KShadow.card : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Padding(
              padding: EdgeInsets.fromLTRB(
                padding.left,
                KSpace.lg,
                padding.right,
                subtitle == null ? KSpace.sm : KSpace.xs,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (step != null) ...[
                    Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: KC.primarySoft,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$step',
                        style: KType.sans(
                          size: 12.5,
                          weight: FontWeight.w700,
                          color: KC.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: KSpace.md),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(top: step == null ? 0 : 2),
                          child: Text(title!, style: KType.serif(size: 17)),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            subtitle!,
                            style: KType.sans(size: 12.5, color: KC.muted, height: 1.4),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) ...[const SizedBox(width: KSpace.sm), trailing!],
                ],
              ),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              padding.left,
              title == null ? padding.top : KSpace.md,
              padding.right,
              padding.bottom,
            ),
            child: child,
          ),
        ],
      ),
    );
  }
}

/// Soft separator.
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

/// `Label            value` row.
class KMetaRow extends StatelessWidget {
  const KMetaRow(
    this.label,
    this.value, {
    super.key,
    this.valueColor = KC.text,
    this.valueWidget,
  });

  final String label;
  final String value;
  final Color valueColor;
  final Widget? valueWidget;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: Text(label, style: KType.sans(size: 13, color: KC.muted)),
          ),
          const SizedBox(width: KSpace.sm),
          Expanded(
            child: valueWidget ??
                Text(
                  value,
                  style: KType.sans(
                    size: 13.5,
                    weight: FontWeight.w600,
                    color: valueColor,
                    height: 1.4,
                  ),
                ),
          ),
        ],
      ),
    );
  }
}

/// Tinted advisory block — used for the "write this down" note, the crisis
/// banner, and anything else that needs to be noticed but not alarming.
class KNote extends StatelessWidget {
  const KNote({
    super.key,
    required this.title,
    required this.body,
    this.icon = Icons.favorite_outline_rounded,
    this.color = KC.secondary,
    this.action,
  });

  final String title;
  final String body;
  final IconData icon;
  final Color color;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(KSpace.lg),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: KRadius.rLg,
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: KSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: KType.serif(size: 15, color: color)),
                    const SizedBox(height: 5),
                    Text(
                      body,
                      style: KType.sans(size: 13, color: KC.text, height: 1.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (action != null) ...[const SizedBox(height: KSpace.md), action!],
        ],
      ),
    );
  }
}
