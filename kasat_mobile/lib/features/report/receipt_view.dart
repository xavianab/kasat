import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/time_format.dart';
import '../../models/country.dart';
import '../../models/incident.dart';
import '../../models/incident_status.dart';
import '../../theme/kasat_theme.dart';
import '../../widgets/kasat_button.dart';
import '../../widgets/panel.dart';
import '../../widgets/soft_backdrop.dart';
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
    final country = countryByCode(incident.countryCode);

    final queued = incident.status == IncidentStatus.queued;

    return Scaffold(
      backgroundColor: KC.canvas,
      body: SoftBackdrop(
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                      KSpace.xl, KSpace.xl, KSpace.xl, KSpace.lg),
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: KC.calmSoft,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check_rounded,
                              size: 19, color: KC.calm),
                        ),
                        const SizedBox(width: KSpace.md),
                        Expanded(
                          child: Text(
                            queued ? 'Saved on this phone' : 'It has been sent',
                            style: KType.serif(size: 24),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: KSpace.md),
                    Text(
                      queued
                          ? 'There was no connection, so nothing left yet. It will send on its own when this phone is back online.'
                          : 'Thank you. Nothing about who you are went with it.',
                      style: KType.sans(size: 14.5, color: KC.muted, height: 1.55),
                    ),
                    const SizedBox(height: KSpace.xl),
                    _TrackingCard(trackingId: incident.trackingId),
                    const SizedBox(height: KSpace.md),
                    const KNote(
                      title: 'Please write this code down',
                      icon: Icons.edit_note_rounded,
                      color: KC.secondary,
                      body: 'It is the only way back to your case. There is no '
                          'email address or phone number on file to recover it '
                          'with — if the code is lost, your report stays with the '
                          'office but you can no longer follow it.',
                    ),
                    const SizedBox(height: KSpace.md),
                    KPanel(
                      title: 'What was sent',
                      trailing: StatusPill(incident.status),
                      child: Column(
                        children: [
                          KMetaRow('Kind', incident.category.label),
                          KMetaRow(
                            'Priority',
                            incident.priority.label,
                            valueColor: incident.priority.color,
                          ),
                          KMetaRow('Country', country?.name ?? incident.countryCode),
                          KMetaRow('Sent', TimeFormat.stamp(incident.submittedAt)),
                          KMetaRow(
                            'Photos',
                            incident.attachments.isEmpty
                                ? 'None'
                                : '${incident.attachments.length}, cleaned first',
                          ),
                          KMetaRow(
                            'Place',
                            incident.location?.coordinateLabel ?? 'Not given',
                          ),
                          KMetaRow('Your name', 'Never asked', valueColor: KC.calm),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(
                    KSpace.lg, KSpace.md, KSpace.lg, KSpace.sm),
                decoration: const BoxDecoration(
                  color: KC.surface,
                  border: Border(top: BorderSide(color: KC.border)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: KButton(
                        label: 'Done',
                        kind: KButtonKind.soft,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    const SizedBox(width: KSpace.sm),
                    Expanded(
                      flex: 2,
                      child: KButton(
                        label: 'Follow my case',
                        icon: Icons.schedule_outlined,
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
      padding: const EdgeInsets.all(KSpace.xl),
      decoration: BoxDecoration(
        color: KC.surface,
        border: Border.all(color: KC.primary, width: 1.6),
        borderRadius: KRadius.rXl,
        boxShadow: KShadow.card,
      ),
      child: Column(
        children: [
          Text(
            'Your code',
            style: KType.sans(size: 13, weight: FontWeight.w600, color: KC.muted),
          ),
          const SizedBox(height: KSpace.md),
          FittedBox(
            child: Text(
              trackingId,
              // The one place monospace survives the warm redesign: this gets
              // copied onto paper, where an ambiguous character is a lost case.
              style: KType.code(size: 36, weight: FontWeight.w700, color: KC.primary),
            ),
          ),
          const SizedBox(height: KSpace.lg),
          KButton(
            label: 'Copy',
            kind: KButtonKind.secondary,
            icon: Icons.content_copy_rounded,
            compact: true,
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: trackingId));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: KC.text,
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.all(KSpace.lg),
                  shape: const RoundedRectangleBorder(borderRadius: KRadius.rMd),
                  duration: const Duration(seconds: 2),
                  content: Text(
                    'Copied',
                    style: KType.sans(size: 14, color: Colors.white),
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
