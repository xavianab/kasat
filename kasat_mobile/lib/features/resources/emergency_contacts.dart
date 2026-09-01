import 'package:flutter/material.dart';

import '../../theme/kasat_theme.dart';

enum ContactKind {
  emergency(label: 'Immediate danger', color: KC.danger, icon: Icons.emergency_share_rounded),
  violence(label: 'Violence & abuse', color: KC.warn, icon: Icons.shield_outlined),
  trafficking(label: 'Trafficking', color: KC.info, icon: Icons.travel_explore_rounded),
  wellbeing(label: 'Crisis support', color: KC.accent, icon: Icons.favorite_border_rounded),
  legal(label: 'Legal aid', color: KC.muted, icon: Icons.gavel_rounded);

  const ContactKind({required this.label, required this.color, required this.icon});

  final String label;
  final Color color;
  final IconData icon;
}

class EmergencyContact {
  const EmergencyContact({
    required this.name,
    required this.number,
    required this.kind,
    required this.region,
    required this.hours,
    required this.blurb,
  });

  final String name;
  final String number;
  final ContactKind kind;
  final String region;
  final String hours;
  final String blurb;

  /// `tel:` payloads must be digits and `+` only.
  String get dialable => number.replaceAll(RegExp(r'[^0-9+]'), '');
}

/// Placeholder directory for the MVP.
///
/// Kasat is intended to be deployed per-jurisdiction, so this list is the one
/// piece of the client that must be replaced before any real rollout — a wrong
/// number here is worse than no number.
const emergencyContacts = <EmergencyContact>[
  EmergencyContact(
    name: 'Local emergency services',
    number: '112',
    kind: ContactKind.emergency,
    region: 'EU / INTL',
    hours: '24/7',
    blurb: 'Single emergency number across the EU and most GSM networks.',
  ),
  EmergencyContact(
    name: 'Emergency services (US/CA)',
    number: '911',
    kind: ContactKind.emergency,
    region: 'US / CA',
    hours: '24/7',
    blurb: 'Police, fire and medical dispatch for North America.',
  ),
  EmergencyContact(
    name: 'National domestic violence hotline',
    number: '1-800-799-7233',
    kind: ContactKind.violence,
    region: 'US',
    hours: '24/7',
    blurb: 'Confidential support and safety planning for survivors.',
  ),
  EmergencyContact(
    name: 'National human trafficking hotline',
    number: '1-888-373-7888',
    kind: ContactKind.trafficking,
    region: 'US',
    hours: '24/7',
    blurb: 'Report suspected trafficking or request victim services.',
  ),
  EmergencyContact(
    name: 'Suicide & crisis lifeline',
    number: '988',
    kind: ContactKind.wellbeing,
    region: 'US',
    hours: '24/7',
    blurb: 'Trained counsellors for anyone in emotional distress.',
  ),
  EmergencyContact(
    name: 'Samaritans',
    number: '116123',
    kind: ContactKind.wellbeing,
    region: 'UK / IE',
    hours: '24/7',
    blurb: 'Free listening service. Does not appear on phone bills.',
  ),
  EmergencyContact(
    name: 'INTERPOL national bureau',
    number: '+33472447000',
    kind: ContactKind.legal,
    region: 'INTL',
    hours: 'Office hours',
    blurb: 'Cross-border case escalation via your national bureau.',
  ),
];
