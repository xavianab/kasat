import 'incident_priority.dart';

enum IncidentCategory {
  harassment(
    code: 'HRSMT',
    label: 'Harassment',
    hint: 'Stalking, threats, coercion, repeated unwanted contact.',
    defaultPriority: IncidentPriority.medium,
  ),
  physicalAssault(
    code: 'ASSLT',
    label: 'Physical Assault',
    hint: 'Bodily harm, battery, or violence against a person.',
    defaultPriority: IncidentPriority.high,
  ),
  fraud(
    code: 'FRAUD',
    label: 'Fraud',
    hint: 'Financial deception, extortion, identity or document fraud.',
    defaultPriority: IncidentPriority.low,
  ),
  trafficking(
    code: 'TRFCK',
    label: 'Trafficking',
    hint: 'Forced labour, movement of persons, exploitation.',
    defaultPriority: IncidentPriority.high,
  ),
  corruption(
    code: 'CRRPT',
    label: 'Abuse of Power',
    hint: 'Bribery, official misconduct, retaliation by authority.',
    defaultPriority: IncidentPriority.medium,
  ),
  criticalEmergency(
    code: 'CRTCL',
    label: 'Critical Emergency',
    hint: 'Life at immediate risk. Routed to the top of dispatch.',
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
