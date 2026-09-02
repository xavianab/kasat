import '../models/incident.dart';

/// The single seam between Kasat's UI and its backend.
///
/// The MVP binds [LocalIncidentRepository]; the Supabase implementation
/// (`incidents` table + realtime channel) drops in behind the same four
/// methods without the feature code changing.
abstract interface class IncidentRepository {
  /// Persists [draft] under an identifier that was already minted on-device.
  ///
  /// When [offline] is true the case is stored as queued and is not handed
  /// to the dispatcher until [flushQueued] runs.
  Future<Incident> submit(
    IncidentDraft draft, {
    required String trackingId,
    bool offline = false,
  });

  /// One-shot fetch. Returns null when no case carries that identifier —
  /// which is indistinguishable from a case the caller isn't allowed to see,
  /// on purpose.
  Future<Incident?> lookup(String trackingId);

  /// Live view of a single case, starting with its current state.
  Stream<Incident?> watch(String trackingId);

  /// Identifiers submitted from this handset, newest first. Held locally only
  /// so the survivor can re-find a code they forgot to write down.
  Future<List<String>> localTrackingIds();

  Future<int> queuedCount();

  /// Moves queued reports to Received. With no live backend this is the
  /// handoff into the local demo dispatcher.
  Future<int> flushQueued();
}
