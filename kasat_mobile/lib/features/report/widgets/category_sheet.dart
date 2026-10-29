import 'package:flutter/material.dart';

import '../../../models/incident_category.dart';
import '../../../theme/kasat_theme.dart';
import '../../../widgets/soft_badge.dart';

/// Category chooser. A native dropdown cannot carry the per-category guidance
/// that helps someone pick correctly under stress, so the trigger reads like a
/// dropdown and opens this instead.
Future<IncidentCategory?> showCategorySheet(
  BuildContext context, {
  IncidentCategory? current,
}) {
  return showModalBottomSheet<IncidentCategory>(
    context: context,
    backgroundColor: KC.surface,
    barrierColor: KC.text.withValues(alpha: 0.28),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(KRadius.xl)),
    ),
    builder: (context) => _CategorySheet(current: current),
  );
}

class _CategorySheet extends StatelessWidget {
  const _CategorySheet({this.current});

  final IncidentCategory? current;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: KSpace.md),
            decoration: BoxDecoration(color: KC.border, borderRadius: KRadius.rPill),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(KSpace.xl, 0, KSpace.xl, KSpace.md),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'What kind of thing happened?',
                    style: KType.serif(size: 20),
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(KSpace.lg, 0, KSpace.lg, KSpace.lg),
              children: [
                for (final category in IncidentCategory.values)
                  _CategoryTile(
                    category: category,
                    selected: category == current,
                    onTap: () => Navigator.of(context).pop(category),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final IncidentCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: KSpace.sm),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(KSpace.lg),
          decoration: BoxDecoration(
            color: selected ? KC.primarySoft : KC.surfaceAlt,
            borderRadius: KRadius.rMd,
            border: Border.all(
              color: selected ? KC.primary : Colors.transparent,
              width: 1.8,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.label,
                      style: KType.sans(
                        size: 15.5,
                        weight: FontWeight.w600,
                        color: selected ? KC.primary : KC.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      category.hint,
                      style: KType.sans(size: 13, color: KC.muted, height: 1.45),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: KSpace.sm),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: SoftBadge(
                  category.defaultPriority.label,
                  color: category.defaultPriority.color,
                  dense: true,
                  size: 11.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
