import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Prompts a person can tick for themselves. Wording is a reminder, not a
/// score — nothing here rates risk or tells them what they must do.
class SafetyPrompt {
  const SafetyPrompt({required this.id, required this.label});

  final String id;
  final String label;
}

class SafetyPlan {
  const SafetyPlan({
    this.checked = const {},
    this.safePlace = '',
    this.trustedPerson = '',
  });

  final Set<String> checked;
  final String safePlace;
  final String trustedPerson;

  bool get isEmpty =>
      checked.isEmpty && safePlace.trim().isEmpty && trustedPerson.trim().isEmpty;

  SafetyPlan copyWith({
    Set<String>? checked,
    String? safePlace,
    String? trustedPerson,
  }) {
    return SafetyPlan(
      checked: checked ?? this.checked,
      safePlace: safePlace ?? this.safePlace,
      trustedPerson: trustedPerson ?? this.trustedPerson,
    );
  }
}

/// Lives only on this phone. It is never attached to a report.
class SafetyPlanStore {
  static const _checksKey = 'kasat.safety_plan.checks.v1';
  static const _placeKey = 'kasat.safety_plan.place.v1';
  static const _personKey = 'kasat.safety_plan.person.v1';

  static const prompts = <SafetyPrompt>[
    SafetyPrompt(
      id: 'place',
      label: 'I have a place I can go if I need to leave.',
    ),
    SafetyPrompt(
      id: 'person',
      label: 'Someone I trust knows I may need help.',
    ),
    SafetyPrompt(
      id: 'number',
      label: 'I know which number I would call.',
    ),
    SafetyPrompt(
      id: 'bag',
      label: 'I have thought about what I would take with me.',
    ),
    SafetyPrompt(
      id: 'path',
      label: 'I have a way to get there.',
    ),
  ];

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  SafetyPlan read() {
    final raw = _prefs.getString(_checksKey);
    final checked = <String>{};
    if (raw != null && raw.isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        checked.addAll(decoded.whereType<String>());
      }
    }
    return SafetyPlan(
      checked: checked,
      safePlace: _prefs.getString(_placeKey) ?? '',
      trustedPerson: _prefs.getString(_personKey) ?? '',
    );
  }

  Future<void> save(SafetyPlan plan) async {
    await _prefs.setString(_checksKey, jsonEncode(plan.checked.toList()..sort()));
    await _prefs.setString(_placeKey, plan.safePlace);
    await _prefs.setString(_personKey, plan.trustedPerson);
  }

  Future<void> toggle(String id) async {
    final plan = read();
    final next = {...plan.checked};
    if (!next.add(id)) next.remove(id);
    await save(plan.copyWith(checked: next));
  }

  Future<void> clear() async {
    await _prefs.remove(_checksKey);
    await _prefs.remove(_placeKey);
    await _prefs.remove(_personKey);
  }
}
