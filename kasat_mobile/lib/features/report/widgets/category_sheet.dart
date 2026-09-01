import 'package:flutter/material.dart';

import '../../../models/incident_category.dart';
import '../../../theme/kasat_theme.dart';
import '../../../widgets/mono_badge.dart';

/// Category chooser. A native dropdown can't carry the per-category guidance
/// that helps someone pick correctly under stress, so the trigger reads like a
/// dropdown and opens this instead.
Future<IncidentCategory?> showCategorySheet(
  BuildContext context, {
  IncidentCategory? current,
}) {
  return showModalBottomSheet<IncidentCategory>(
    context: context,
    backgroundColor: KC.surface,
    barrierColor: Colors.black.withValues(alpha: 0.72),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
      side: BorderSide(color: KC.border),
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
            width: 32,
            height: 3,
            margin: const EdgeInsets.symmetric(vertical: KSpace.md),
            decoration: BoxDecoration(
              color: KC.borderHi,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(KSpace.lg, 0, KSpace.lg, KSpace.md),
            child: Row(
              children: [
                Text('INCIDENT CLASSIFICATION', style: KType.label(color: KC.text)),
                const Spacer(),
                MonoBadge('${IncidentCategory.values.length} TYPES', size: 9, dense: true),
              ],
            ),
          ),
          const Divider(height: 1, color: KC.border),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: IncidentCategory.values.length,
              separatorBuilder: (_, _) => const Divider(height: 1, color: KC.border),
              itemBuilder: (context, i) {
                final category = IncidentCategory.values[i];
                return _CategoryTile(
                  category: category,
                  selected: category == current,
                  onTap: () => Navigator.of(context).pop(category),
                );
              },
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        color: selected ? KC.accent.withValues(alpha: 0.07) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: KSpace.lg, vertical: KSpace.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        category.label,
                        style: KType.sans(
                          size: 14,
                          weight: FontWeight.w700,
                          color: selected ? KC.accent : KC.text,
                        ),
                      ),
                      const SizedBox(width: KSpace.sm),
                      MonoBadge(category.code, size: 9, dense: true, color: KC.faint),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    category.hint,
                    style: KType.sans(size: 11.5, color: KC.muted, height: 1.35),
                  ),
                ],
              ),
            ),
            const SizedBox(width: KSpace.sm),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: MonoBadge(
                category.defaultPriority.code,
                color: category.defaultPriority.color,
                filled: true,
                dense: true,
                size: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
