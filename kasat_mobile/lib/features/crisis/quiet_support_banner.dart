import 'package:flutter/material.dart';

import '../../app.dart';
import '../../theme/kasat_theme.dart';
import '../../widgets/soft_badge.dart';
import '../shell/shell_view.dart';

/// Quiet offer of help. Never a modal, never red, never auto-navigates.
class QuietSupportBanner extends StatelessWidget {
  const QuietSupportBanner({super.key, required this.visible});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    final i18n = KasatScope.of(context).i18n;

    return Padding(
      padding: const EdgeInsets.only(bottom: KSpace.lg),
      child: Material(
        color: KC.calmSoft,
        borderRadius: KRadius.rLg,
        child: InkWell(
          borderRadius: KRadius.rLg,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const ShellView(initialTab: ShellTab.resources),
            ),
          ),
          child: Container(
            padding: const EdgeInsets.all(KSpace.lg),
            decoration: BoxDecoration(
              borderRadius: KRadius.rLg,
              border: Border.all(color: KC.calm.withValues(alpha: 0.28)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.favorite_outline_rounded, size: 20, color: KC.calm),
                const SizedBox(width: KSpace.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        i18n.t('crisis.quiet'),
                        style: KType.sans(size: 14, height: 1.45, color: KC.text),
                      ),
                      const SizedBox(height: 8),
                      SoftBadge(
                        i18n.t('crisis.openHelp'),
                        color: KC.calm,
                        dense: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
