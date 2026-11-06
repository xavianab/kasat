import 'package:flutter/material.dart';

import '../theme/kasat_theme.dart';

enum IncidentPriority {
  low(code: 'P4', label: 'Low'),
  medium(code: 'P3', label: 'Medium'),
  high(code: 'P2', label: 'High'),
  critical(code: 'P1', label: 'Critical');

  const IncidentPriority({
    required this.code,
    required this.label,
  });

  final String code;
  final String label;

  Color get color => switch (this) {
        IncidentPriority.low => KC.muted,
        IncidentPriority.medium => KC.primary,
        IncidentPriority.high => KC.secondary,
        IncidentPriority.critical => KC.urgent,
      };

  static IncidentPriority fromCode(String code) {
    return IncidentPriority.values.firstWhere(
      (p) => p.code == code,
      orElse: () => IncidentPriority.medium,
    );
  }
}
