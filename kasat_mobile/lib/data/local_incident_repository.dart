import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/kasat_config.dart';
import '../models/incident.dart';
import '../models/incident_category.dart';
import '../models/incident_status.dart';
import 'incident_repository.dart';

/// On-device store that stands in for Supabase during the MVP.
///
/// Everything lives in the app sandbox, which means the zero-knowledge story
/// holds trivially here — there is no network. When the Supabase binding
/// lands, this class stays useful as the offline outbox.
class LocalIncidentRepository implements IncidentRepository {
  static const _incidentsKey = 'kasat.incidents.v1';
  static const _localIdsKey = 'kasat.local_ids.v1';

  final _cache = <String, Incident>{};
  final _changes = StreamController<String>.broadcast();
  final _timers = <Timer>[];

  late SharedPreferences _prefs;
  List<String> _localIds = const [];

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();

    final raw = _prefs.getString(_incidentsKey);
    if (raw != null) {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      for (final entry in decoded.entries) {
        _cache[entry.key] = Incident.fromJson(entry.value as Map<String, dynamic>);
      }
    }
    _localIds = _prefs.getStringList(_localIdsKey) ?? const [];

    if (_cache.isEmpty) {
      await _seedDemoCases();
    }
  }

  @override
  Future<Incident> submit(IncidentDraft draft, {required String trackingId}) async {
    final now = DateTime.now();
    final incident = Incident(
      trackingId: trackingId,
      category: draft.category,
      description: draft.description.trim(),
      priority: draft.priority,
      status: IncidentStatus.received,
      countryCode: draft.countryCode,
      submittedAt: now,
      updatedAt: now,
      location: draft.location,
      attachments: draft.attachments,
      history: [
        StatusEvent(
          status: IncidentStatus.received,
          at: now,
          actor: 'INTAKE',
          note: 'Anonymous payload accepted. No originator metadata retained.',
        ),
      ],
    );

    _cache[trackingId] = incident;
    _localIds = [trackingId, ..._localIds.where((id) => id != trackingId)];
    await _persist();
    _changes.add(trackingId);

    if (KasatConfig.demoDispatch) {
      _scheduleDemoTriage(trackingId);
    }
    return incident;
  }

  @override
  Future<Incident?> lookup(String trackingId) async {
    // A deliberate flat delay: a fast "not found" versus a slow "found" would
    // leak whether a code exists to anyone timing the response.
    await Future<void>.delayed(const Duration(milliseconds: 450));
    return _cache[trackingId];
  }

  @override
  Stream<Incident?> watch(String trackingId) async* {
    yield _cache[trackingId];
    yield* _changes.stream
        .where((id) => id == trackingId)
        .map((_) => _cache[trackingId]);
  }

  @override
  Future<List<String>> localTrackingIds() async => List.unmodifiable(_localIds);

  /// Appends a status change. In production this is the dashboard's write; it
  /// is exposed here so the demo dispatcher and widget tests share one path.
  Future<void> advance(
    String trackingId,
    IncidentStatus status, {
    String actor = 'STN-04',
    String? note,
  }) async {
    final current = _cache[trackingId];
    if (current == null || current.status == status) return;

    final now = DateTime.now();
    _cache[trackingId] = current.copyWith(
      status: status,
      updatedAt: now,
      assignedStation: actor,
      history: [
        ...current.history,
        StatusEvent(status: status, at: now, actor: actor, note: note),
      ],
    );
    await _persist();
    _changes.add(trackingId);
  }

  void _scheduleDemoTriage(String trackingId) {
    _timers.add(
      Timer(KasatConfig.demoTriageDelay, () {
        advance(
          trackingId,
          IncidentStatus.underInvestigation,
          note: 'Case claimed by duty officer. Evidence review opened.',
        );
      }),
    );
  }

  Future<void> _persist() async {
    final encoded = jsonEncode(
      _cache.map((key, value) => MapEntry(key, value.toJson())),
    );
    await _prefs.setString(_incidentsKey, encoded);
    await _prefs.setStringList(_localIdsKey, _localIds);
  }

  /// Two reference cases so the lookup view has something to resolve against
  /// on a fresh install. Both codes are printed on the lookup screen.
  Future<void> _seedDemoCases() async {
    final now = DateTime.now();

    Incident demo({
      required String id,
      required IncidentCategory category,
      required IncidentStatus status,
      required Duration age,
      required String description,
      required List<StatusEvent> history,
    }) {
      return Incident(
        trackingId: id,
        category: category,
        description: description,
        priority: category.defaultPriority,
        status: status,
        countryCode: 'ET',
        submittedAt: now.subtract(age),
        updatedAt: history.last.at,
        history: history,
        assignedStation: status == IncidentStatus.received ? null : 'STN-04',
      );
    }

    final a = now.subtract(const Duration(hours: 31));
    final b = now.subtract(const Duration(days: 9));

    final cases = [
      demo(
        id: 'KST-4RT7Q',
        category: IncidentCategory.harassment,
        status: IncidentStatus.underInvestigation,
        age: const Duration(hours: 31),
        description:
            'Repeated unwanted contact from a former colleague over three weeks, '
            'escalating to threats made outside my workplace.',
        history: [
          StatusEvent(
            status: IncidentStatus.received,
            at: a,
            actor: 'INTAKE',
            note: 'Anonymous payload accepted.',
          ),
          StatusEvent(
            status: IncidentStatus.underInvestigation,
            at: a.add(const Duration(hours: 6)),
            actor: 'STN-04',
            note: 'Assigned to duty officer. Statement corroboration in progress.',
          ),
        ],
      ),
      demo(
        id: 'KST-9WM2K',
        category: IncidentCategory.fraud,
        status: IncidentStatus.resolved,
        age: const Duration(days: 9),
        description:
            'Fraudulent transfer requests sent from a spoofed account claiming to '
            'be my landlord.',
        history: [
          StatusEvent(status: IncidentStatus.received, at: b, actor: 'INTAKE'),
          StatusEvent(
            status: IncidentStatus.underInvestigation,
            at: b.add(const Duration(days: 1)),
            actor: 'STN-04',
          ),
          StatusEvent(
            status: IncidentStatus.resolved,
            at: b.add(const Duration(days: 6)),
            actor: 'STN-04',
            note: 'Account frozen by the issuing bank. Case closed.',
          ),
        ],
      ),
    ];

    for (final c in cases) {
      _cache[c.trackingId] = c;
    }
    await _persist();
  }

  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
    _changes.close();
  }
}
