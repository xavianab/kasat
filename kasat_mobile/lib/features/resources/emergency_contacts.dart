import 'package:flutter/material.dart';

import '../../theme/kasat_theme.dart';

/// The kinds of help Kasat routes to. Ordered by how urgent they are, because
/// the resources screen and the crisis banner both render in this order.
enum ContactKind {
  federalPolice(
    label: 'Federal Police',
    icon: Icons.local_police_outlined,
    color: KC.urgent,
  ),
  womensAffairs(
    label: "Women's Affairs",
    icon: Icons.diversity_1_outlined,
    color: KC.primary,
  ),
  ngo(
    label: 'Support organisations',
    icon: Icons.volunteer_activism_outlined,
    color: KC.secondary,
  ),
  legalAid(
    label: 'Legal aid',
    icon: Icons.balance_outlined,
    color: KC.calm,
  );

  const ContactKind({required this.label, required this.icon, required this.color});

  final String label;
  final IconData icon;
  final Color color;
}

class EmergencyContact {
  const EmergencyContact({
    required this.name,
    required this.number,
    required this.kind,
    required this.hours,
    required this.blurb,
    this.verified = false,
  });

  final String name;

  /// Dialled as-is. While [verified] is false this is a placeholder and the UI
  /// refuses to dial it.
  final String number;

  final ContactKind kind;
  final String hours;
  final String blurb;

  /// Flipped to true only when a real number has been confirmed for the
  /// jurisdiction. Nothing dials an unverified entry: sending someone to a
  /// wrong number in an emergency is worse than showing them none.
  final bool verified;

  /// `tel:` payloads accept digits and `+` only.
  String get dialable => number.replaceAll(RegExp(r'[^0-9+]'), '');

  bool get isCrisisLine =>
      kind == ContactKind.federalPolice || kind == ContactKind.womensAffairs;
}

/// Emergency contacts keyed by ISO 3166-1 alpha-2 country code.
///
/// EVERY NUMBER BELOW IS A PLACEHOLDER. They exist so the routing, grouping,
/// and crisis banner can be built and tested; they are not dialable and are
/// marked `verified: false` so the UI says so out loud. Replace the numbers
/// and flip `verified` to true per entry as each one is confirmed.
const emergencyContactsByCountry = <String, List<EmergencyContact>>{
  'ET': [
    EmergencyContact(
      name: 'Ethiopian Federal Police',
      number: '+251-000-000-001',
      kind: ContactKind.federalPolice,
      hours: 'Placeholder',
      blurb: 'National police response and criminal reporting.',
    ),
    EmergencyContact(
      name: 'Ministry of Women and Social Affairs hotline',
      number: '+251-000-000-002',
      kind: ContactKind.womensAffairs,
      hours: 'Placeholder',
      blurb: 'Government support line for gender-based violence cases.',
    ),
    EmergencyContact(
      name: 'Regional Women\u2019s Affairs Bureau',
      number: '+251-000-000-003',
      kind: ContactKind.womensAffairs,
      hours: 'Placeholder',
      blurb: 'Regional caseworkers and referral to shelter services.',
    ),
    EmergencyContact(
      name: 'Survivor support NGO \u2014 counselling',
      number: '+251-000-000-004',
      kind: ContactKind.ngo,
      hours: 'Placeholder',
      blurb: 'Confidential counselling and safety planning.',
    ),
    EmergencyContact(
      name: 'Survivor support NGO \u2014 shelter placement',
      number: '+251-000-000-005',
      kind: ContactKind.ngo,
      hours: 'Placeholder',
      blurb: 'Emergency accommodation and relocation assistance.',
    ),
    EmergencyContact(
      name: 'Legal aid clinic',
      number: '+251-000-000-006',
      kind: ContactKind.legalAid,
      hours: 'Placeholder',
      blurb: 'Free representation and help filing a formal complaint.',
    ),
  ],
};

/// Contacts for [countryCode], grouped by kind and ordered by urgency.
///
/// An unlaunched country returns empty rather than falling back to another
/// country's numbers — a Kenyan number shown to someone in Somalia is a
/// failure, not a graceful degradation.
List<EmergencyContact> contactsForCountry(String? countryCode) {
  if (countryCode == null) return const [];
  return emergencyContactsByCountry[countryCode] ?? const [];
}

/// The one or two lines the crisis banner offers. Deliberately short: a banner
/// with six numbers on it is a banner nobody reads.
List<EmergencyContact> crisisLinesForCountry(String? countryCode) {
  return contactsForCountry(countryCode).where((c) => c.isCrisisLine).take(2).toList();
}

Map<ContactKind, List<EmergencyContact>> groupedContactsForCountry(String? countryCode) {
  final grouped = <ContactKind, List<EmergencyContact>>{};
  for (final kind in ContactKind.values) {
    final matching = contactsForCountry(countryCode).where((c) => c.kind == kind).toList();
    if (matching.isNotEmpty) grouped[kind] = matching;
  }
  return grouped;
}
