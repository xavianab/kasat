import '../models/incident.dart';

/// The single seam between Kasat's UI and its backend.
abstract interface class IncidentRepository {
  /// Persists [draft] locally (and remotely as status `draft` when a backend
  /// is configured). Police cannot see drafts.
  Future<Incident> submit(
    IncidentDraft draft, {
    required String trackingId,
    bool offline = false,
  });

  /// Moves a draft to `sent` and sets `sent_at`. This is the only write that
  /// makes the row visible to her station.
  Future<Incident?> sendToPolice(String trackingId);

  Future<Incident?> lookup(String trackingId);

  Stream<Incident?> watch(String trackingId);

  Future<List<String>> localTrackingIds();

  Future<int> queuedCount();

  /// Sends queued (offline) reports. Each one is posted as a send, not a draft.
  Future<int> flushQueued();

  /// Creates an immediate URGENT-priority emergency report ("I'm in Danger")
  /// with live GPS coordinates and pins it to the police queue.
  Future<Incident> triggerEmergency({
    required String trackingId,
    required String countryCode,
    double? latitude,
    double? longitude,
    double? accuracyMeters,
    bool silentMode = false,
    bool offline = false,
  });

  /// Updates the live GPS coordinates on an active emergency report.
  Future<void> updateEmergencyLocation(
    String trackingId, {
    required double latitude,
    required double longitude,
    double? accuracyMeters,
  });

  /// Stops live location sharing on an active emergency report.
  Future<void> stopEmergencyLocation(String trackingId);

  /// Sends the survivor's silent approach confirmation response
  /// (`'can_come_out'` or `'abuser_present_do_not_knock'`) after an officer
  /// taps "I have arrived" on the portal.
  Future<Incident?> submitApproachResponse(
    String trackingId, {
    required String response,
  });

  /// One-way self-identification: links the survivor's name and contact details
  /// in the separate `report_identities` table for [trackingId]. Irreversible.
  Future<Incident?> revealIdentity(
    String trackingId, {
    required String fullName,
    required String channel,
    required String handle,
    String? safeNote,
  });
}
