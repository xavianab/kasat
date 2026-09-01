import 'package:flutter/material.dart';

import '../../../core/crisis_detection.dart';
import '../../../core/dialer.dart';
import '../../../theme/kasat_theme.dart';
import '../../resources/emergency_contacts.dart';

/// Offered when what the survivor has written suggests danger is still present.
///
/// The lines come from the country table, so a survivor in one jurisdiction is
/// never shown another jurisdiction's number. It is an offer, not an
/// interruption: the form underneath stays usable and nothing is submitted.
class CrisisBanner extends StatelessWidget {
  const CrisisBanner({
    super.key,
    required this.signal,
    required this.countryCode,
  });

  final CrisisSignal signal;
  final String? countryCode;

  @override
  Widget build(BuildContext context) {
    if (!signal.triggered) return const SizedBox.shrink();

    final lines = crisisLinesForCountry(countryCode);

    return Container(
      padding: const EdgeInsets.all(KSpace.lg),
      decoration: BoxDecoration(
        color: KC.urgentSoft,
        borderRadius: KRadius.rLg,
        border: Border.all(color: KC.urgent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.favorite_outline_rounded, size: 20, color: KC.urgent),
              const SizedBox(width: KSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Do you need help right now?',
                      style: KType.serif(size: 17, color: KC.urgent),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${signal.reason ?? ''} You can reach someone directly — '
                      'filing this report can wait.',
                      style: KType.sans(size: 13.5, color: KC.text, height: 1.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (lines.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: KSpace.md),
              child: Text(
                'No confirmed lines are available for your country yet. Please '
                'use a number you know.',
                style: KType.sans(size: 13, color: KC.muted, height: 1.5),
              ),
            )
          else
            for (final contact in lines)
              Padding(
                padding: const EdgeInsets.only(top: KSpace.md),
                child: _CrisisLine(
                  contact: contact,
                  onTap: () => Dialer.call(context, contact),
                ),
              ),
        ],
      ),
    );
  }
}

class _CrisisLine extends StatelessWidget {
  const _CrisisLine({required this.contact, required this.onTap});

  final EmergencyContact contact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: KC.surface,
      borderRadius: KRadius.rMd,
      child: InkWell(
        borderRadius: KRadius.rMd,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(KSpace.md),
          decoration: BoxDecoration(
            borderRadius: KRadius.rMd,
            border: Border.all(color: KC.urgent.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: KC.urgentSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(contact.kind.icon, size: 18, color: KC.urgent),
              ),
              const SizedBox(width: KSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.name,
                      style: KType.sans(size: 14, weight: FontWeight.w600, height: 1.3),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      contact.verified ? contact.number : 'Number not confirmed yet',
                      style: KType.sans(
                        size: 12.5,
                        color: contact.verified ? KC.secondary : KC.faint,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                contact.verified ? Icons.call_rounded : Icons.info_outline_rounded,
                size: 20,
                color: contact.verified ? KC.urgent : KC.faint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
