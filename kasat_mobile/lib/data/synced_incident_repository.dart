import '../models/incident.dart';
import '../models/incident_status.dart';
import 'incident_repository.dart';
import 'local_incident_repository.dart';
import 'remote_reports_client.dart';

/// On-device store plus optional shared `reports` backend.
class SyncedIncidentRepository implements IncidentRepository {
  SyncedIncidentRepository({
    required this.local,
    RemoteReportsClient? remote,
  }) : _remote = remote ?? RemoteReportsClient();

  final LocalIncidentRepository local;
  final RemoteReportsClient _remote;

  @override
  Future<Incident> submit(
    IncidentDraft draft, {
    required String trackingId,
    bool offline = false,
  }) async {
    final incident =
        await local.submit(draft, trackingId: trackingId, offline: offline);
    if (!offline && _remote.enabled && incident.status == IncidentStatus.draft) {
      try {
        final synced = await _remote.insertDraft(incident, strictPhoto: true);
        await local.updateIncident(synced);
        return synced;
      } catch (_) {
        // Flaky connection or timeout while nominally online: mark as queued
        // so flushQueued() retries both the report and any attached photos.
        final queued = await local.markQueued(trackingId);
        return queued ?? incident;
      }
    }
    return incident;
  }

  @override
  Future<Incident?> sendToPolice(String trackingId) async {
    final current = await local.lookup(trackingId);
    if (current == null) return null;
    if (_remote.enabled) {
      try {
        if (current.isEmergency) {
          final sentEmergency = await _remote.insertEmergency(current);
          await local.updateIncident(sentEmergency);
          return await local.sendToPolice(trackingId);
        }
        var working = current;
        if (working.status == IncidentStatus.draft ||
            working.status == IncidentStatus.queued) {
          try {
            working = await _remote.insertDraft(working, strictPhoto: true);
            await local.updateIncident(working);
          } catch (_) {
            // Row may already exist from submit; send() will still upload any
            // pending photo with strictPhoto: true.
          }
        }
        final remoteSent = await _remote.send(working, strictPhoto: true);
        if (remoteSent != null) {
          await local.updateIncident(remoteSent);
        }
      } catch (_) {
        // Send or photo upload timed out on a flaky connection: mark queued
        // so flushQueued() will retry the photo upload and send automatically.
        return await local.markQueued(trackingId);
      }
    }
    return local.sendToPolice(trackingId);
  }

  @override
  Future<Incident?> lookup(String trackingId) async {
    final current = await local.lookup(trackingId);
    if (!_remote.enabled) return current;
    try {
      final remote = await _remote.lookup(trackingId, current);
      if (remote != null) {
        if (current != null && remote.status != current.status) {
          await local.advance(trackingId, remote.status, actor: 'STATION');
        }
        await local.updateIncident(remote);
        return remote;
      }
      return current;
    } catch (_) {
      return current;
    }
  }

  @override
  Stream<Incident?> watch(String trackingId) async* {
    yield await lookup(trackingId);
    yield* local.watch(trackingId).asyncMap((_) => lookup(trackingId));
  }

  @override
  Future<List<String>> localTrackingIds() => local.localTrackingIds();

  @override
  Future<int> queuedCount() => local.queuedCount();

  @override
  Future<int> flushQueued() async {
    final ids = await local.localTrackingIds();
    var n = 0;
    for (final id in ids) {
      final row = await local.lookup(id);
      if (row?.status != IncidentStatus.queued) continue;
      final after = await sendToPolice(id);
      if (after?.status == IncidentStatus.sent) {
        n++;
      }
    }
    return n;
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
    final incident = await local.triggerEmergency(
      trackingId: trackingId,
      countryCode: countryCode,
      latitude: latitude,
      longitude: longitude,
      accuracyMeters: accuracyMeters,
      silentMode: silentMode,
      offline: offline,
    );
    if (!offline && _remote.enabled) {
      try {
        final synced = await _remote.insertEmergency(incident);
        await local.updateIncident(synced);
        return synced;
      } catch (_) {
        final queued = await local.markQueued(trackingId);
        return queued ?? incident;
      }
    }
    return incident;
  }

  @override
  Future<void> updateEmergencyLocation(
    String trackingId, {
    required double latitude,
    required double longitude,
    double? accuracyMeters,
  }) async {
    await local.updateEmergencyLocation(
      trackingId,
      latitude: latitude,
      longitude: longitude,
      accuracyMeters: accuracyMeters,
    );
    if (_remote.enabled) {
      try {
        await _remote.updateEmergencyLocation(
          trackingId,
          latitude: latitude,
          longitude: longitude,
          accuracyMeters: accuracyMeters,
          accessSecret: (await local.lookup(trackingId))?.accessSecret,
        );
      } catch (_) {
        // Next location tick will retry.
      }
    }
  }

  @override
  Future<void> stopEmergencyLocation(String trackingId) async {
    await local.stopEmergencyLocation(trackingId);
    if (_remote.enabled) {
      try {
        await _remote.stopEmergencyLocation(
          trackingId,
          accessSecret: (await local.lookup(trackingId))?.accessSecret,
        );
      } catch (_) {
        // Local state already stopped.
      }
    }
  }

  @override
  Future<Incident?> submitApproachResponse(
    String trackingId, {
    required String response,
  }) async {
    final updatedLocal = await local.submitApproachResponse(
      trackingId,
      response: response,
    );
    if (_remote.enabled) {
      final synced = await _remote.submitApproachResponse(
        trackingId,
        response: response,
        local: updatedLocal,
      );
      if (synced != null) {
        await local.updateIncident(synced);
        return synced;
      }
    }
    return updatedLocal;
  }

  @override
  Future<Incident?> revealIdentity(
    String trackingId, {
    required String fullName,
    required String channel,
    required String handle,
    String? safeNote,
  }) async {
    if (_remote.enabled) {
      await _remote.revealIdentity(
        trackingId,
        fullName: fullName,
        channel: channel,
        handle: handle,
        safeNote: safeNote,
        accessSecret: (await local.lookup(trackingId))?.accessSecret,
      );
    }
    return local.revealIdentity(
      trackingId,
      fullName: fullName,
      channel: channel,
      handle: handle,
      safeNote: safeNote,
    );
  }
}
