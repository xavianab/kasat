import 'package:flutter/material.dart';

import '../theme/kasat_theme.dart';

enum IncidentStatus {
  received(
    code: 'RECEIVED',
    label: 'Received',
    blurb: 'Your report has arrived. Nobody has opened it yet.',
    color: KC.primary,
    step: 0,
  ),
  underInvestigation(
    code: 'UNDER_INVESTIGATION',
    label: 'Under Investigation',
    blurb: 'Someone has opened your case and is working on it.',
    color: KC.secondary,
    step: 1,
  ),
  resolved(
    code: 'RESOLVED',
    label: 'Resolved',
    blurb: 'Your case has been closed by the office handling it.',
    color: KC.calm,
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
