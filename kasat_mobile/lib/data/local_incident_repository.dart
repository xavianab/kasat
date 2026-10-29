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
  Future<Incident> submit(
    IncidentDraft draft, {
    required String trackingId,
    bool offline = false,
  }) async {
    final now = DateTime.now();
    final initial = offline ? IncidentStatus.queued : IncidentStatus.draft;
    final clientSha =
        draft.attachments.isNotEmpty ? draft.attachments.first.sha256 : null;
    final incident = Incident(
      trackingId: trackingId,
      category: draft.category,
      description: draft.description.trim(),
      priority: draft.priority,
      status: initial,
      countryCode: draft.countryCode,
      submittedAt: now,
      updatedAt: now,
      location: draft.location,
      attachments: draft.attachments,
      isEmergency: draft.isEmergency,
      liveLatitude: draft.liveLatitude,
      liveLongitude: draft.liveLongitude,
      locationUpdatedAt: draft.liveLatitude != null ? now : null,
      liveLocationActive: draft.isEmergency,
      evidenceSha256: null,
      clientEvidenceSha256: clientSha,
      evidenceIntegrityStatus:
          clientSha != null ? 'pending_server_hash' : 'none',
      history: [
        StatusEvent(
          status: initial,
          at: now,
          actor: 'INTAKE',
          note: offline
              ? 'Held on this phone. Will send when a connection is available.'
              : 'Anonymous payload accepted. No originator metadata retained.',
        ),
      ],
    );

    _cache[trackingId] = incident;
    _localIds = [trackingId, ..._localIds.where((id) => id != trackingId)];
    await _persist();
    _changes.add(trackingId);

    return incident;
  }

  @override
  Future<Incident?> sendToPolice(String trackingId) async {
    final current = _cache[trackingId];
    if (current == null) return null;
    if (current.status == IncidentStatus.sent ||
        current.status == IncidentStatus.underReview ||
        current.status == IncidentStatus.resolved) {
      return current;
    }
    await advance(
      trackingId,
      IncidentStatus.sent,
      actor: 'INTAKE',
      note: 'Sent to the station queue. No originator metadata retained.',
    );
    if (KasatConfig.demoDispatch) {
      _scheduleDemoTriage(trackingId);
    }
    return _cache[trackingId];
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

  @override
  Future<int> queuedCount() async =>
      _cache.values.where((i) => i.status == IncidentStatus.queued).length;

  @override
  Future<int> flushQueued() async {
    final waiting = _cache.values
        .where((i) => i.status == IncidentStatus.queued)
        .map((i) => i.trackingId)
        .toList();
    for (final id in waiting) {
      await sendToPolice(id);
    }
    return waiting.length;
  }

  /// Marks an existing report as `queued` when a network call fails or times
  /// out while the phone appeared to be online, so `flushQueued()` retries it.
  Future<Incident?> markQueued(String trackingId) async {
    final current = _cache[trackingId];
    if (current == null) return null;
    if (current.status == IncidentStatus.queued) return current;
    final now = DateTime.now();
    final updated = current.copyWith(
      status: IncidentStatus.queued,
      updatedAt: now,
      history: [
        ...current.history,
        StatusEvent(
          status: IncidentStatus.queued,
          at: now,
          actor: 'INTAKE',
          note: 'Connection timed out. Queued on this phone to retry automatically.',
        ),
      ],
    );
    _cache[trackingId] = updated;
    await _persist();
    _changes.add(trackingId);
    return updated;
  }

  /// Updates stored metadata on a local incident (e.g. uploaded photo key or
  /// server-verified UTC receipt timestamp).
  Future<Incident?> updateIncident(Incident updated) async {
    _cache[updated.trackingId] = updated;
    await _persist();
    _changes.add(updated.trackingId);
    return updated;
  }

  @override
  Future<Incident> triggerEmergency({
    required String trackingId,
    required String countryCode,
    double? latitude,
    double? longitude,
    double? accuracyMeters,
    bool silentMode = false,
    bool offline = false,
  }) async {
    final now = DateTime.now();
    final initialStatus = offline ? IncidentStatus.queued : IncidentStatus.sent;
    final incident = Incident(
      trackingId: trackingId,
      category: IncidentCategory.criticalEmergency,
      description:
          'URGENT: Survivor activated the I\'M IN DANGER emergency button. '
          'Immediate police response requested.',
      priority: IncidentCategory.criticalEmergency.defaultPriority,
      status: initialStatus,
      countryCode: countryCode,
      submittedAt: now,
      updatedAt: now,
      isEmergency: true,
      silentMode: silentMode,
      liveLatitude: latitude,
      liveLongitude: longitude,
      liveAccuracyMeters: accuracyMeters,
      locationUpdatedAt: latitude != null ? now : null,
      liveLocationActive: true,
      history: [
        StatusEvent(
          status: initialStatus,
          at: now,
          actor: 'EMERGENCY',
          note: offline
              ? 'Emergency alert queued offline. Will transmit immediately on signal.'
              : 'Emergency alert dispatched to station queue with live location.',
        ),
      ],
    );
    _cache[trackingId] = incident;
    _localIds = [trackingId, ..._localIds.where((id) => id != trackingId)];
    await _persist();
    _changes.add(trackingId);
    return incident;
  }

  @override
  Future<void> updateEmergencyLocation(
    String trackingId, {
    required double latitude,
    required double longitude,
    double? accuracyMeters,
  }) async {
    final current = _cache[trackingId];
    if (current == null) return;
    final now = DateTime.now();
    _cache[trackingId] = current.copyWith(
      liveLatitude: latitude,
      liveLongitude: longitude,
      liveAccuracyMeters: accuracyMeters,
      locationUpdatedAt: now,
      liveLocationActive: true,
      updatedAt: now,
    );
    await _persist();
    _changes.add(trackingId);
  }

  @override
  Future<void> stopEmergencyLocation(String trackingId) async {
    final current = _cache[trackingId];
    if (current == null) return;
    final now = DateTime.now();
    _cache[trackingId] = current.copyWith(
      liveLocationActive: false,
      updatedAt: now,
      history: [
        ...current.history,
        StatusEvent(
          status: current.status,
          at: now,
          actor: 'SURVIVOR',
          note: 'Live location sharing stopped by survivor.',
        ),
      ],
    );
    await _persist();
    _changes.add(trackingId);
  }

  @override
  Future<Incident?> submitApproachResponse(
    String trackingId, {
    required String response,
  }) async {
    final current = _cache[trackingId];
    if (current == null) return null;
    final now = DateTime.now().toUtc();
    final updated = current.copyWith(
      approachResponse: response,
      approachRespondedAtUtc: now,
      updatedAt: now,
    );
    _cache[trackingId] = updated;
    await _persist();
    _changes.add(trackingId);
    return updated;
  }

  /// Simulates an officer tapping "I have arrived" in local/unit tests.
  Future<Incident?> simulateOfficerArrival(
    String trackingId, {
    int windowSec = 90,
  }) async {
    final current = _cache[trackingId];
    if (current == null) return null;
    final now = DateTime.now().toUtc();
    final updated = current.copyWith(
      officerArrivedAtUtc: now,
      approachResponseWindowSec: windowSec,
      updatedAt: now,
    );
    _cache[trackingId] = updated;
    await _persist();
    _changes.add(trackingId);
    return updated;
  }

  @override
  Future<Incident?> revealIdentity(
    String trackingId, {
    required String fullName,
    required String channel,
    required String handle,
    String? safeNote,
  }) async {
    final current = _cache[trackingId];
    if (current == null) return null;
    if (current.identityRevealed) return current;
    final now = DateTime.now();
    final updated = current.copyWith(
      identityRevealed: true,
      revealedName: fullName.trim(),
      revealedChannel: channel,
      revealedHandle: handle.trim(),
      updatedAt: now,
      history: [
        ...current.history,
        StatusEvent(
          status: current.status,
          at: now,
          actor: 'SURVIVOR',
          note: 'You chose to share your identity with police for this case.',
        ),
      ],
    );
    _cache[trackingId] = updated;
    await _persist();
    _changes.add(trackingId);
    return updated;
  }

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
          IncidentStatus.underReview,
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
        assignedStation: status.step <= 0 ? null : 'STN-04',
      );
    }

    final a = now.subtract(const Duration(hours: 31));
    final b = now.subtract(const Duration(days: 9));

    final cases = [
      demo(
        id: 'KST-4RT7Q',
        category: IncidentCategory.harassment,
        status: IncidentStatus.underReview,
        age: const Duration(hours: 31),
        description:
            'Repeated unwanted contact from a former colleague over three weeks, '
            'escalating to threats made outside my workplace.',
        history: [
          StatusEvent(
            status: IncidentStatus.sent,
            at: a,
            actor: 'INTAKE',
            note: 'Anonymous payload accepted.',
          ),
          StatusEvent(
            status: IncidentStatus.underReview,
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
          StatusEvent(status: IncidentStatus.sent, at: b, actor: 'INTAKE'),
          StatusEvent(
            status: IncidentStatus.underReview,
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
