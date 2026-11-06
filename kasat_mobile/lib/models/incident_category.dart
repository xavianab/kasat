import 'incident_priority.dart';

enum IncidentCategory {
  sexualViolence(
    code: 'sexual',
    label: 'Sexual violence',
    hint: 'Sexual contact or an assault that was sexual.',
    defaultPriority: IncidentPriority.high,
  ),
  domesticViolence(
    code: 'domestic',
    label: 'Domestic violence',
    hint: 'Harm from a partner or someone in the home.',
    defaultPriority: IncidentPriority.high,
  ),
  forcedMarriage(
    code: 'marriage',
    label: 'Forced / child marriage',
    hint: 'A marriage you did not choose, or one involving a child.',
    defaultPriority: IncidentPriority.high,
  ),
  childAbuse(
    code: 'child',
    label: 'Child abuse',
    hint: 'A child being hurt, threatened, or neglected.',
    defaultPriority: IncidentPriority.high,
  ),
  harassment(
    code: 'HRSMT',
    label: 'Harassment',
    hint: 'Being followed, threatened, or contacted again and again.',
    defaultPriority: IncidentPriority.medium,
  ),
  physicalAssault(
    code: 'ASSLT',
    label: 'Physical assault',
    hint: 'Someone hurt you or used force against you.',
    defaultPriority: IncidentPriority.high,
  ),
  fraud(
    code: 'FRAUD',
    label: 'Fraud',
    hint: 'Money taken by deception, or documents used against you.',
    defaultPriority: IncidentPriority.low,
  ),
  trafficking(
    code: 'TRFCK',
    label: 'Trafficking',
    hint: 'Being forced to work, or moved somewhere against your will.',
    defaultPriority: IncidentPriority.high,
  ),
  corruption(
    code: 'CRRPT',
    label: 'Abuse of power',
    hint: 'Someone in authority using their position against you.',
    defaultPriority: IncidentPriority.medium,
  ),
  other(
    code: 'other',
    label: 'Other',
    hint: 'Something else that does not fit the choices above.',
    defaultPriority: IncidentPriority.low,
  ),
  criticalEmergency(
    code: 'CRTCL',
    label: 'Critical emergency',
    hint: 'Someone is in danger right now. Seen first.',
    defaultPriority: IncidentPriority.critical,
  );

  const IncidentCategory({
    required this.code,
    required this.label,
    required this.hint,
    required this.defaultPriority,
  });

  final String code;
  final String label;
  final String hint;
  final IncidentPriority defaultPriority;

  /// Categories offered on the report form. Critical is not a category.
  /// Urgency is [Incident.isEmergency], not a type.
  static const choices = <IncidentCategory>[
    sexualViolence,
    domesticViolence,
    forcedMarriage,
    childAbuse,
    harassment,
    other,
  ];

  /// The category selected on the open report, so an urgent alert can keep it.
  static IncidentCategory? chosen;

  static IncidentCategory fromCode(String code) {
    return IncidentCategory.values.firstWhere(
      (c) => c.code == code,
      orElse: () => IncidentCategory.harassment,
    );
  }
}
