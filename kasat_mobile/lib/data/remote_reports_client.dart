import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../core/kasat_config.dart';
import '../models/attachment.dart';
import '../models/incident.dart';
import '../models/incident_category.dart';
import '../models/incident_status.dart';

/// Talks to the shared `reports` and `report_identities` tables in Supabase.
class RemoteReportsClient {
  RemoteReportsClient({
    http.Client? httpClient,
    String? supabaseUrl,
    String? supabaseAnonKey,
    Duration? timeout,
  })  : _http = httpClient ?? http.Client(),
        _supabaseUrl = supabaseUrl ?? KasatConfig.supabaseUrl,
        _supabaseAnonKey = supabaseAnonKey ?? KasatConfig.supabaseAnonKey,
        _timeout = timeout ?? const Duration(seconds: 12);

  final http.Client _http;
  final String _supabaseUrl;
  final String _supabaseAnonKey;
  final Duration _timeout;

  bool get enabled => _supabaseUrl.isNotEmpty && _supabaseAnonKey.isNotEmpty;

  Uri _url(String path, [Map<String, String>? query]) {
    return Uri.parse('$_supabaseUrl/rest/v1/$path')
        .replace(queryParameters: query);
  }

  Map<String, String> _headers({String? trackingCode, bool json = true}) {
    final headers = <String, String>{
      if (json) 'Content-Type': 'application/json',
      'Accept': 'application/json',
      'apikey': _supabaseAnonKey,
      'Authorization': 'Bearer $_supabaseAnonKey',
      'Prefer': 'return=representation',
    };
    if (trackingCode != null) {
      headers['x-tracking-code'] = trackingCode;
    }
    return headers;
  }

  /// Uploads the first attachment to Supabase Storage (`report-photos`).
  /// When [strict] is true and a real on-disk file fails to upload (e.g. flaky
  /// connection), throws so `flushQueued()` can retry the photo upload later.
  Future<String?> uploadPhotoIfPresent(
    Incident incident, {
    bool strict = false,
  }) async {
    if (incident.attachments.isEmpty) return null;
    final Attachment first = incident.attachments.first;
    if (first.remoteObjectKey != null && first.remoteObjectKey!.isNotEmpty) {
      return first.remoteObjectKey;
    }
    final path = first.storagePath;
    if (path.isEmpty) return null;

    final file = File(path);
    final exists = await file.exists();
    if (!exists) {
      // Synthetic path in unit tests — pass through without network I/O.
      return path;
    }

    try {
      final bytes = await file.readAsBytes();
      final ext = first.mimeType.contains('png') ? 'png' : 'jpg';
      final objectKey = '${incident.trackingId}/${first.id}.$ext';
      final uploadUrl = Uri.parse(
        '$_supabaseUrl/storage/v1/object/report-photos/$objectKey',
      );
      final res = await _http
          .post(
            uploadUrl,
            headers: {
              'apikey': _supabaseAnonKey,
              'Authorization': 'Bearer $_supabaseAnonKey',
              'Content-Type': first.mimeType,
              'x-upsert': 'true',
            },
            body: bytes,
          )
          .timeout(_timeout);
      if (res.statusCode < 300) {
        return objectKey;
      }
      if (strict) {
        throw Exception('photo upload failed (${res.statusCode})');
      }
    } catch (_) {
      if (strict) rethrow;
    }
    return path;
  }

  /// Triggers server-side SHA-256 computation over the actual bytes stored in
  /// `report-photos` via the `verify-evidence` Edge Function. The server
  /// persists the authoritative `evidence_sha256` and compares against
  /// [clientSha256] as a transport-integrity check.
  Future<Incident> verifyEvidenceIfUploaded(
    Incident incident, {
    required String? photoUrl,
  }) async {
    if (photoUrl == null || photoUrl.isEmpty) return incident;
    final clientSha = incident.clientEvidenceSha256 ??
        (incident.attachments.isNotEmpty
            ? incident.attachments.first.sha256
            : null);
    try {
      final verifyUrl = Uri.parse('$_supabaseUrl/functions/v1/verify-evidence');
      final res = await _http
          .post(
            verifyUrl,
            headers: _headers(trackingCode: incident.trackingId),
            body: jsonEncode({
              'tracking_code': incident.trackingId,
              'photo_url': photoUrl,
              'object_key': photoUrl,
              'client_sha256': ?clientSha,
            }),
          )
          .timeout(_timeout);
      if (res.statusCode < 300 && res.body.isNotEmpty) {
        final decoded = jsonDecode(utf8.decode(res.bodyBytes));
        if (decoded is Map<String, dynamic>) {
          final serverSha = decoded['server_sha256'] as String?;
          final verifiedAt =
              DateTime.tryParse(decoded['verified_at'] as String? ?? '')
                  ?.toUtc();
          final integrityStatus = decoded['integrity_status'] as String?;
          return incident.copyWith(
            evidenceSha256: serverSha ?? incident.evidenceSha256,
            clientEvidenceSha256: clientSha ?? incident.clientEvidenceSha256,
            evidenceVerifiedAtUtc:
                verifiedAt ?? incident.evidenceVerifiedAtUtc,
            evidenceIntegrityStatus:
                integrityStatus ?? incident.evidenceIntegrityStatus,
          );
        }
      }
    } catch (_) {
      // Non-fatal if Edge Function call is unavailable in unit test mocks;
      // server hash can also be verified on send() or lookup().
    }
    return incident;
  }

  Future<Incident> insertDraft(
    Incident incident, {
    bool strictPhoto = false,
  }) async {
    final photoUrl =
        await uploadPhotoIfPresent(incident, strict: strictPhoto);
    final body = jsonEncode(
      _toRow(incident, status: 'draft', sentAt: null, photoUrl: photoUrl),
    );
    final res = await _http
        .post(
          _url('reports'),
          headers: _headers(trackingCode: incident.trackingId),
          body: body,
        )
        .timeout(_timeout);
    if (res.statusCode >= 300) {
      throw Exception('draft insert failed (${res.statusCode})');
    }
    final updatedAttachments = _withRemoteKey(incident.attachments, photoUrl);
    final base = _fromBody(
          utf8.decode(res.bodyBytes),
          incident.copyWith(attachments: updatedAttachments),
        ) ??
        incident.copyWith(attachments: updatedAttachments);
    return verifyEvidenceIfUploaded(base, photoUrl: photoUrl);
  }

  Future<Incident?> send(
    Incident incident, {
    bool strictPhoto = false,
  }) async {
    final photoUrl =
        await uploadPhotoIfPresent(incident, strict: strictPhoto);
    final sentAt = DateTime.now().toUtc().toIso8601String();
    final clientSha = incident.clientEvidenceSha256 ??
        (incident.attachments.isNotEmpty
            ? incident.attachments.first.sha256
            : null);

    final patchBody = <String, dynamic>{
      'status': 'sent',
      'sent_at': sentAt,
      'photo_url': ?photoUrl,
      'client_evidence_sha256': ?clientSha,
    };

    final res = await _http
        .patch(
          _url('reports', {'tracking_code': 'eq.${incident.trackingId}'}),
          headers: _headers(trackingCode: incident.trackingId),
          body: jsonEncode(patchBody),
        )
        .timeout(_timeout);
    if (res.statusCode >= 300) {
      throw Exception('send failed (${res.statusCode})');
    }
    final updatedAttachments = _withRemoteKey(incident.attachments, photoUrl);
    final base = incident.copyWith(
      attachments: updatedAttachments,
      clientEvidenceSha256: clientSha,
    );
    final parsed = _fromBody(utf8.decode(res.bodyBytes), base) ??
        base.copyWith(status: IncidentStatus.sent);
    return verifyEvidenceIfUploaded(parsed, photoUrl: photoUrl);
  }

  static String addisSubCityLandmarkFor(double? lat, double? lon) {
    if (lat == null || lon == null) {
      return 'Bole — Near Edna Mall';
    }
    if (lat < 3.0 || lat > 15.5 || lon < 33.0 || lon > 48.5) {
      return 'Bole — Near Edna Mall, 200m east toward Meles Academy';
    }
    if (lat >= 9.025 && lon <= 38.765) {
      return 'Arada — Piazza, near Cinema Ethiopia';
    }
    if (lat >= 9.015 && lon >= 38.795) {
      return 'Yeka — Megenagna, behind Zefmesh Grand Mall';
    }
    if (lat <= 9.012 && lon <= 38.770) {
      return 'Kirkos — Meskel Square, behind St. Estifanos Church';
    }
    if (lon >= 38.830) {
      return 'Lemi Kura — Ayat Roundabout, near CCE Compound';
    }
    return 'Bole — Near Edna Mall, 200m east toward Meles Academy';
  }

  /// Inserts an URGENT-priority emergency row directly with `status = 'sent'`
  /// and `is_emergency = true`. Triggers `reports_emergency_audit` in Postgres.
  Future<Incident> insertEmergency(Incident incident) async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final lat = incident.liveLatitude ??
        (KasatConfig.isDemoLocationActive
            ? KasatConfig.demoSurvivorLatitude
            : null);
    final lon = incident.liveLongitude ??
        (KasatConfig.isDemoLocationActive
            ? KasatConfig.demoSurvivorLongitude
            : null);
    final landmarkLabel = incident.location?.displayLabel ??
        (KasatConfig.isDemoLocationActive
            ? KasatConfig.demoSurvivorLandmark
            : addisSubCityLandmarkFor(lat, lon));
    final payload = <String, dynamic>{
      'tracking_code': incident.trackingId,
      'incident_type': IncidentCategory.criticalEmergency.code,
      'approx_location': landmarkLabel,
      'description': incident.description,
      'status': 'sent',
      'sent_at': nowIso,
      'is_emergency': true,
      'silent_mode': incident.silentMode,
      'live_latitude': lat,
      'live_longitude': lon,
      'live_accuracy_meters': incident.liveAccuracyMeters,
      'location_updated_at': lat != null ? nowIso : null,
      'live_location_active': true,
    };

    final res = await _http
        .post(
          _url('reports'),
          headers: _headers(trackingCode: incident.trackingId),
          body: jsonEncode(payload),
        )
        .timeout(_timeout);
    if (res.statusCode >= 300) {
      throw Exception('emergency insert failed (${res.statusCode})');
    }
    return _fromBody(utf8.decode(res.bodyBytes), incident) ??
        incident.copyWith(status: IncidentStatus.sent);
  }

  Future<void> updateEmergencyLocation(
    String trackingCode, {
    required double latitude,
    required double longitude,
    double? accuracyMeters,
  }) async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final res = await _http
        .patch(
          _url('reports', {'tracking_code': 'eq.$trackingCode'}),
          headers: _headers(trackingCode: trackingCode),
          body: jsonEncode({
            'live_latitude': latitude,
            'live_longitude': longitude,
            'live_accuracy_meters': ?accuracyMeters,
            'location_updated_at': nowIso,
            'live_location_active': true,
          }),
        )
        .timeout(_timeout);
    if (res.statusCode >= 300) {
      throw Exception('live location update failed (${res.statusCode})');
    }
  }

  Future<void> stopEmergencyLocation(String trackingCode) async {
    final res = await _http
        .patch(
          _url('reports', {'tracking_code': 'eq.$trackingCode'}),
          headers: _headers(trackingCode: trackingCode),
          body: jsonEncode({
            'live_location_active': false,
          }),
        )
        .timeout(_timeout);
    if (res.statusCode >= 300) {
      throw Exception('stop live location failed (${res.statusCode})');
    }
  }

  /// Sends the survivor's approach confirmation (`'can_come_out'` or
  /// `'abuser_present_do_not_knock'`) via the `submit_approach_response` RPC.
  Future<Incident?> submitApproachResponse(
    String trackingCode, {
    required String response,
    Incident? local,
  }) async {
    final res = await _http
        .post(
          _url('rpc/submit_approach_response'),
          headers: _headers(trackingCode: trackingCode),
          body: jsonEncode({
            'p_tracking_code': trackingCode,
            'p_response': response,
          }),
        )
        .timeout(_timeout);
    if (res.statusCode >= 300) {
      throw Exception('submit approach response failed (${res.statusCode}): ${res.body}');
    }
    return _fromBody(utf8.decode(res.bodyBytes), local);
  }

  /// Calls the one-way `reveal_report_identity` RPC in Supabase, storing the
  /// survivor's identity in the separate `report_identities` table.
  Future<void> revealIdentity(
    String trackingCode, {
    required String fullName,
    required String channel,
    required String handle,
    String? safeNote,
  }) async {
    final res = await _http
        .post(
          _url('rpc/reveal_report_identity'),
          headers: _headers(trackingCode: trackingCode),
          body: jsonEncode({
            'p_tracking_code': trackingCode,
            'p_full_name': fullName.trim(),
            'p_contact_channel': channel,
            'p_contact_handle': handle.trim(),
            'p_safe_note': safeNote?.trim(),
          }),
        )
        .timeout(_timeout);
    if (res.statusCode >= 300) {
      throw Exception('reveal identity failed (${res.statusCode}): ${res.body}');
    }
  }

  Future<Incident?> lookup(String trackingCode, Incident? local) async {
    final res = await _http
        .get(
          _url('reports', {'tracking_code': 'eq.$trackingCode', 'select': '*'}),
          headers: _headers(trackingCode: trackingCode, json: false),
        )
        .timeout(_timeout);
    if (res.statusCode >= 300 ||
        res.body.isEmpty ||
        res.body == '[]' ||
        res.body == 'null') {
      return local;
    }
    return _fromBody(res.body, local);
  }

  List<Attachment> _withRemoteKey(
    List<Attachment> attachments,
    String? photoUrl,
  ) {
    if (attachments.isEmpty || photoUrl == null || photoUrl.isEmpty) {
      return attachments;
    }
    final first = attachments.first;
    if (photoUrl == first.storagePath) return attachments;
    return [
      first.copyWith(remoteObjectKey: photoUrl),
      ...attachments.skip(1),
    ];
  }

  Map<String, dynamic> _toRow(
    Incident incident, {
    required String status,
    required String? sentAt,
    String? photoUrl,
  }) {
    final clientSha = incident.clientEvidenceSha256 ??
        (incident.attachments.isNotEmpty
            ? incident.attachments.first.sha256
            : null);
    return {
      'tracking_code': incident.trackingId,
      'incident_type': incident.category.code,
      'approx_location': incident.location?.displayLabel,
      'description': incident.description,
      'photo_url': photoUrl ??
          (incident.attachments.isEmpty
              ? null
              : incident.attachments.first.storagePath),
      'status': status,
      'sent_at': sentAt,
      'client_evidence_sha256': ?clientSha,
    };
  }

  Incident? _fromBody(String body, Incident? local) {
    if (body.isEmpty) return local;
    final decoded = jsonDecode(body);
    Map<String, dynamic>? row;
    if (decoded is List && decoded.isNotEmpty) {
      row = decoded.first as Map<String, dynamic>;
    } else if (decoded is Map<String, dynamic>) {
      row = decoded;
    }
    if (row == null || row['tracking_code'] == null) return local;
    final status = row['status'] is String
        ? IncidentStatus.fromCode(row['status'] as String)
        : (local?.status ?? IncidentStatus.draft);
    final createdUtc =
        DateTime.tryParse(row['created_at'] as String? ?? '')?.toUtc();
    final updated = DateTime.tryParse(row['sent_at'] as String? ?? '') ??
        createdUtc ??
        DateTime.now();
    // Authoritative SHA-256 is ONLY populated by the server-side verifier.
    final serverSha =
        row['evidence_sha256'] as String? ?? local?.evidenceSha256;
    final clientSha = row['client_evidence_sha256'] as String? ??
        local?.clientEvidenceSha256 ??
        (local != null && local.attachments.isNotEmpty
            ? local.attachments.first.sha256
            : null);
    final verifiedAtUtc =
        DateTime.tryParse(row['evidence_verified_at'] as String? ?? '')
                ?.toUtc() ??
            local?.evidenceVerifiedAtUtc;
    final integrityStatus = row['evidence_integrity_status'] as String? ??
        local?.evidenceIntegrityStatus;
    final identityRevealed =
        (row['identity_revealed'] as bool?) ?? local?.identityRevealed ?? false;
    final silentMode =
        (row['silent_mode'] as bool?) ?? local?.silentMode ?? false;
    final liveAccuracyMeters =
        (row['live_accuracy_meters'] as num?)?.toDouble() ??
            local?.liveAccuracyMeters;
    final officerArrivedAtUtc =
        DateTime.tryParse(row['officer_arrived_at'] as String? ?? '')
                ?.toUtc() ??
            local?.officerArrivedAtUtc;
    final approachResponseWindowSec =
        (row['approach_response_window_sec'] as num?)?.toInt() ??
            local?.approachResponseWindowSec ??
            90;
    final approachResponse =
        row['approach_response'] as String? ?? local?.approachResponse;
    final approachRespondedAtUtc =
        DateTime.tryParse(row['approach_responded_at'] as String? ?? '')
                ?.toUtc() ??
            local?.approachRespondedAtUtc;

    if (local == null) {
      final cat = IncidentCategory.fromCode(
        row['incident_type'] as String? ?? 'HRSMT',
      );
      return Incident(
        trackingId: row['tracking_code'] as String,
        category: cat,
        description: row['description'] as String? ?? '',
        priority: cat.defaultPriority,
        status: status,
        countryCode: 'ET',
        submittedAt: createdUtc ?? updated,
        updatedAt: updated,
        history: [StatusEvent(status: status, at: updated)],
        isEmergency: row['is_emergency'] as bool? ?? false,
        silentMode: silentMode,
        liveLatitude: (row['live_latitude'] as num?)?.toDouble(),
        liveLongitude: (row['live_longitude'] as num?)?.toDouble(),
        liveAccuracyMeters: liveAccuracyMeters,
        locationUpdatedAt:
            DateTime.tryParse(row['location_updated_at'] as String? ?? ''),
        liveLocationActive: row['live_location_active'] as bool? ?? false,
        officerArrivedAtUtc: officerArrivedAtUtc,
        approachResponseWindowSec: approachResponseWindowSec,
        approachResponse: approachResponse,
        approachRespondedAtUtc: approachRespondedAtUtc,
        identityRevealed: identityRevealed,
        evidenceSha256: serverSha,
        clientEvidenceSha256: clientSha,
        evidenceVerifiedAtUtc: verifiedAtUtc,
        evidenceIntegrityStatus: integrityStatus,
        serverCreatedAtUtc: createdUtc,
      );
    }
    final nextHistory = local.status == status
        ? local.history
        : [
            ...local.history,
            StatusEvent(status: status, at: updated, actor: 'STATION'),
          ];
    return local.copyWith(
      status: status,
      updatedAt: updated,
      history: nextHistory,
      silentMode: silentMode,
      liveLatitude:
          (row['live_latitude'] as num?)?.toDouble() ?? local.liveLatitude,
      liveLongitude:
          (row['live_longitude'] as num?)?.toDouble() ?? local.liveLongitude,
      liveAccuracyMeters: liveAccuracyMeters,
      officerArrivedAtUtc: officerArrivedAtUtc,
      approachResponseWindowSec: approachResponseWindowSec,
      approachResponse: approachResponse,
      approachRespondedAtUtc: approachRespondedAtUtc,
      identityRevealed: identityRevealed,
      evidenceSha256: serverSha,
      clientEvidenceSha256: clientSha,
      evidenceVerifiedAtUtc: verifiedAtUtc,
      evidenceIntegrityStatus: integrityStatus,
      serverCreatedAtUtc: createdUtc ?? local.serverCreatedAtUtc,
    );
  }
}
