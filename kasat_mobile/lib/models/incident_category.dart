import 'incident_priority.dart';

enum IncidentCategory {
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

  static IncidentCategory fromCode(String code) {
    return IncidentCategory.values.firstWhere(
      (c) => c.code == code,
      orElse: () => IncidentCategory.harassment,
    );
  }
}
