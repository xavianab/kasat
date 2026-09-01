import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/time_format.dart';
import '../../models/incident.dart';
import '../../theme/kasat_theme.dart';
import '../../widgets/grid_backdrop.dart';
import '../../widgets/kasat_button.dart';
import '../../widgets/panel.dart';
import '../../widgets/status_pill.dart';

/// Post-submission confirmation. The tracking code is the entire payload of
/// this screen — everything else is arranged around making sure the survivor
/// leaves with it.
class ReceiptView extends StatelessWidget {
  const ReceiptView({super.key, required this.incident, required this.onTrack});

  final Incident incident;
  final VoidCallback onTrack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KC.canvas,
      body: GridBackdrop(
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(KSpace.lg),
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: KC.accent.withValues(alpha: 0.12),
                            border: Border.all(color: KC.accent),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Icon(Icons.check_rounded, size: 14, color: KC.accent),
                        ),
                        const SizedBox(width: KSpace.sm),
                        Text(
                          'REPORT ACCEPTED',
                          style: KType.mono(
                            size: 12,
                            weight: FontWeight.w800,
                            color: KC.accent,
                            tracking: 1.6,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: KSpace.xl),
                    _TrackingCard(trackingId: incident.trackingId),
                    const SizedBox(height: KSpace.md),
                    KPanel(
                      title: 'Filed payload',
                      trailing: StatusPill(incident.status),
                      child: Column(
                        children: [
                          KMetaRow('Category', incident.category.label),
                          KMetaRow(
                            'Priority',
                            incident.priority.label,
                            valueColor: incident.priority.color,
                          ),
                          KMetaRow('Filed at', TimeFormat.stamp(incident.submittedAt)),
                          KMetaRow(
                            'Evidence',
                            incident.attachments.isEmpty
                                ? 'None attached'
                                : '${incident.attachments.length} file(s) · metadata stripped',
                          ),
                          KMetaRow(
                            'Location',
                            incident.location?.coordinateLabel ?? 'Not provided',
                          ),
                          KMetaRow('Originator', 'NOT RECORDED', valueColor: KC.accent),
                        ],
                      ),
                    ),
                    const SizedBox(height: KSpace.md),
                    const _CustodyWarning(),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(KSpace.md),
                decoration: const BoxDecoration(
                  color: KC.surface,
                  border: Border(top: BorderSide(color: KC.border)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: KButton(
                        label: 'Close',
                        kind: KButtonKind.outline,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    const SizedBox(width: KSpace.sm),
                    Expanded(
                      flex: 2,
                      child: KButton(
                        label: 'Track this case',
                        icon: Icons.radar_rounded,
                        onPressed: () {
                          Navigator.of(context).pop();
                          onTrack();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrackingCard extends StatelessWidget {
  const _TrackingCard({required this.trackingId});

  final String trackingId;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(KSpace.lg),
      decoration: BoxDecoration(
        color: KC.surface,
        border: Border.all(color: KC.accent),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            'YOUR TRACKING CODE',
            style: KType.mono(size: 9.5, weight: FontWeight.w700, color: KC.muted, tracking: 2),
          ),
          const SizedBox(height: KSpace.md),
          FittedBox(
            child: Text(
              trackingId,
              style: KType.mono(
                size: 38,
                weight: FontWeight.w800,
                color: KC.accent,
                tracking: 3,
              ),
            ),
          ),
          const SizedBox(height: KSpace.md),
          KButton(
            label: 'Copy code',
            kind: KButtonKind.outline,
            icon: Icons.content_copy_rounded,
            compact: true,
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: trackingId));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: KC.surfaceHi,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                    side: const BorderSide(color: KC.accentDeep),
                  ),
                  duration: const Duration(seconds: 2),
                  content: Text(
                    '$trackingId copied to clipboard',
                    style: KType.mono(size: 11, color: KC.accent),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CustodyWarning extends StatelessWidget {
  const _CustodyWarning();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(KSpace.md),
      decoration: BoxDecoration(
        color: KC.warn.withValues(alpha: 0.06),
        border: Border.all(color: KC.warn.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(Icons.warning_amber_rounded, size: 15, color: KC.warn),
          ),
          const SizedBox(width: KSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('WRITE THIS CODE DOWN', style: KType.label(color: KC.warn)),
                const SizedBox(height: 5),
                Text(
                  'It is the only link between you and this case. We hold no '
                  'email, phone number or account to recover it with — if the '
                  'code is lost, the report stays filed but you can no longer '
                  'follow it.',
                  style: KType.sans(size: 11.5, color: KC.muted, height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
