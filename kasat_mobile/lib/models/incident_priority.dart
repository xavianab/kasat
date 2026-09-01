import 'package:flutter/material.dart';

import '../theme/kasat_theme.dart';

enum IncidentPriority {
  low(code: 'P4', label: 'Low', color: KC.muted),
  medium(code: 'P3', label: 'Medium', color: KC.primary),
  high(code: 'P2', label: 'High', color: KC.secondary),
  critical(code: 'P1', label: 'Critical', color: KC.urgent);

  const IncidentPriority({
    required this.code,
    required this.label,
    required this.color,
  });

  final String code;
  final String label;
  final Color color;

  static IncidentPriority fromCode(String code) {
    return IncidentPriority.values.firstWhere(
      (p) => p.code == code,
      orElse: () => IncidentPriority.medium,
    );
  }
}
