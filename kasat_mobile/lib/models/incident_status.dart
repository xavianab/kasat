import 'package:flutter/material.dart';

import '../theme/kasat_theme.dart';

enum IncidentStatus {
  received(
    code: 'RECEIVED',
    label: 'Received',
    blurb: 'Payload sealed and queued. No officer has opened it yet.',
    color: KC.info,
    step: 0,
  ),
  underInvestigation(
    code: 'UNDER_INVESTIGATION',
    label: 'Under Investigation',
    blurb: 'A station has claimed this case and is actively working it.',
    color: KC.warn,
    step: 1,
  ),
  resolved(
    code: 'RESOLVED',
    label: 'Resolved',
    blurb: 'The case has been closed out by the assigned station.',
    color: KC.accent,
    step: 2,
  );

  const IncidentStatus({
    required this.code,
    required this.label,
    required this.blurb,
    required this.color,
    required this.step,
  });

  final String code;
  final String label;
  final String blurb;
  final Color color;
  final int step;

  static IncidentStatus fromCode(String code) {
    return IncidentStatus.values.firstWhere(
      (s) => s.code == code,
      orElse: () => IncidentStatus.received,
    );
  }
}
