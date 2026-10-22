import 'package:flutter/material.dart';

import '../theme/kasat_theme.dart';

enum IncidentStatus {
  queued(
    code: 'queued',
    label: 'Waiting to send',
    blurb: 'Saved on this phone. It will send when there is a connection.',
    color: KC.muted,
    step: -1,
  ),
  draft(
    code: 'draft',
    label: 'Draft',
    blurb: 'Saved. Police cannot see it until you send it.',
    color: KC.muted,
    step: -1,
  ),
  sent(
    code: 'sent',
    label: 'Sent',
    blurb: 'Your report has arrived. An officer has not opened it yet.',
    color: KC.primary,
    step: 0,
  ),
  underReview(
    code: 'under_review',
    label: 'Under review',
    blurb: 'Someone has opened your case and is working on it.',
    color: KC.secondary,
    step: 1,
  ),
  resolved(
    code: 'resolved',
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
    switch (code) {
      case 'queued':
      case 'QUEUED':
        return IncidentStatus.queued;
      case 'draft':
        return IncidentStatus.draft;
      case 'sent':
      case 'RECEIVED':
        return IncidentStatus.sent;
      case 'under_review':
      case 'UNDER_INVESTIGATION':
        return IncidentStatus.underReview;
      case 'resolved':
      case 'RESOLVED':
        return IncidentStatus.resolved;
      default:
        return IncidentStatus.draft;
    }
  }
}
