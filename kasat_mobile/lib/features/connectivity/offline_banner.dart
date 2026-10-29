import 'package:flutter/material.dart';

import '../../app.dart';
import '../../theme/kasat_theme.dart';

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, required this.offline, this.queued = 0});

  final bool offline;
  final int queued;

  @override
  Widget build(BuildContext context) {
    if (!offline && queued == 0) return const SizedBox.shrink();
    final i18n = KasatScope.of(context).i18n;

    return Padding(
      padding: const EdgeInsets.only(bottom: KSpace.md),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(KSpace.md),
        decoration: BoxDecoration(
          color: KC.secondarySoft,
          borderRadius: KRadius.rMd,
          border: Border.all(color: KC.secondary.withValues(alpha: 0.22)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (offline)
              Text(i18n.t('offline.banner'), style: KType.sans(size: 13, height: 1.45)),
            if (queued > 0) ...[
              if (offline) const SizedBox(height: 6),
              Text(
                i18n.t(
                  queued == 1 ? 'offline.queued' : 'offline.queuedMany',
                  {'count': '$queued'},
                ),
                style: KType.sans(size: 13, weight: FontWeight.w600, color: KC.secondary),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              i18n.t('offline.periodicNote'),
              style: KType.sans(size: 11.5, color: KC.muted, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
