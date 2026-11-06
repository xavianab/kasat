import 'package:flutter/material.dart';

import '../theme/kasat_theme.dart';

enum IncidentStatus {
  queued(
    code: 'queued',
    label: 'Waiting to send',
    blurb: 'Saved on this phone. It will send when there is a connection.',
    step: -1,
  ),
  draft(
    code: 'draft',
    label: 'Draft',
    blurb: 'Saved. Police cannot see it until you send it.',
    step: -1,
  ),
  sent(
    code: 'sent',
    label: 'Sent',
    blurb: 'Your report has arrived. An officer has not opened it yet.',
    step: 0,
  ),
  underReview(
    code: 'under_review',
    label: 'Under review',
    blurb: 'Someone has opened your case and is working on it.',
    step: 1,
  ),
  resolved(
    code: 'resolved',
    label: 'Resolved',
    blurb: 'Your case has been closed by the office handling it.',
    step: 2,
  );

  const IncidentStatus({
    required this.code,
    required this.label,
    required this.blurb,
    required this.step,
  });

  final String code;
  final String label;
  final String blurb;
  final int step;

  Color get color => switch (this) {
        IncidentStatus.queued || IncidentStatus.draft => KC.muted,
        IncidentStatus.sent => KC.primary,
        IncidentStatus.underReview => KC.secondary,
        IncidentStatus.resolved => KC.calm,
      };

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
