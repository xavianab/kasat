import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../core/kasat_config.dart';
import '../models/attachment.dart';
import '../models/incident.dart';
import '../models/incident_category.dart';
import '../models/incident_status.dart';

/// Talks to shared Kasat reports through narrow SECURITY DEFINER RPCs.
/// Anon never reads or writes `reports` directly.
class RemoteReportsClient {
  RemoteReportsClient({
    http.Client? httpClient,
    String? supabaseUrl,
    String? supabaseAnonKey,
    Duration? timeout,
    String? deviceSecret,
  })  : _http = httpClient ?? http.Client(),
        _supabaseUrl = supabaseUrl ?? KasatConfig.supabaseUrl,
        _supabaseAnonKey = supabaseAnonKey ?? KasatConfig.supabaseAnonKey,
        _timeout = timeout ?? const Duration(seconds: 12),
        _deviceSecretOverride = deviceSecret;

  final http.Client _http;
  final String _supabaseUrl;
  final String _supabaseAnonKey;
  final Duration _timeout;
  final String? _deviceSecretOverride;
  static const _deviceSecretPrefsKey = 'kasat.device_rl_secret.v1';

  bool get enabled => _supabaseUrl.isNotEmpty && _supabaseAnonKey.isNotEmpty;

  Uri _rpc(String name) => Uri.parse('$_supabaseUrl/rest/v1/rpc/$name');

  Uri _fn(String name) => Uri.parse('$_supabaseUrl/functions/v1/$name');

  Map<String, String> _jsonHeaders() => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'apikey': _supabaseAnonKey,
        'Authorization': 'Bearer $_supabaseAnonKey',
      };

  Future<String> _deviceSecret() async {
    if (_deviceSecretOverride != null && _deviceSecretOverride.isNotEmpty) {
      return _deviceSecretOverride;
    }
    final prefs = await SharedPreferences.getInstance();
    var secret = prefs.getString(_deviceSecretPrefsKey);
    if (secret == null || secret.isEmpty) {
      secret = base64Url.encode(
        List<int>.generate(32, (_) => Random.secure().nextInt(256)),
      );
      await prefs.setString(_deviceSecretPrefsKey, secret);
    }
    return secret;
  }

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
      return path;
    }
    final accessSecret = incident.accessSecret;
    if (accessSecret == null || accessSecret.isEmpty) {
      if (strict) {
        throw Exception('photo upload requires access secret');
      }
      return path;
    }

    try {
      final bytes = await file.readAsBytes();
      final ext = first.mimeType.contains('png')
          ? 'png'
          : first.mimeType.contains('webp')
              ? 'webp'
              : 'jpg';
      final objectId = RegExp(
        r'^[0-9a-fA-F-]{36}$',
      ).hasMatch(first.id)
          ? first.id
          : const Uuid().v4();
      final objectKey = '${incident.trackingId}/$objectId.$ext';
      final res = await _http
          .post(
            _fn('upload-evidence'),
            headers: {
              'apikey': _supabaseAnonKey,
              'Authorization': 'Bearer $_supabaseAnonKey',
              'Content-Type': first.mimeType,
              'x-kasat-access-secret': accessSecret,
              'x-kasat-object-key': objectKey,
              if (first.sha256 != null && first.sha256!.isNotEmpty)
                'x-kasat-client-sha256': first.sha256!,
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

  Future<Incident> verifyEvidenceIfUploaded(
    Incident incident, {
    required String? photoUrl,
  }) async {
    if (photoUrl == null || photoUrl.isEmpty) return incident;
    final secret = incident.accessSecret;
    if (secret == null || secret.isEmpty) return incident;
    try {
      final res = await _http
          .post(
            _rpc('lookup_own_report'),
            headers: _jsonHeaders(),
            body: jsonEncode({'p_access_secret': secret}),
          )
          .timeout(_timeout);
      if (res.statusCode < 300 && res.body.isNotEmpty) {
        return _fromBody(utf8.decode(res.bodyBytes), incident) ?? incident;
      }
    } catch (_) {}
    return incident;
  }

  Future<Incident> insertDraft(
    Incident incident, {
    bool strictPhoto = false,
  }) async {
    final clientSha = incident.clientEvidenceSha256 ??
        (incident.attachments.isNotEmpty
            ? incident.attachments.first.sha256
            : null);
    final createRes = await _http
        .post(
          _rpc('create_draft_report'),
          headers: _jsonHeaders(),
          body: jsonEncode({
            'p_incident_type': incident.category.code,
            'p_description': incident.description,
            'p_approx_location': incident.location?.displayLabel,
            'p_client_sha256': ?clientSha,
            'p_tracking_code': incident.trackingId,
          }),
        )
        .timeout(_timeout);
    if (createRes.statusCode >= 300) {
      throw Exception('draft insert failed (${createRes.statusCode})');
    }
    var created = _fromBody(utf8.decode(createRes.bodyBytes), incident) ?? incident;
    final photoUrl = await uploadPhotoIfPresent(created, strict: strictPhoto);
    final updatedAttachments = _withRemoteKey(created.attachments, photoUrl);
    final base = created.copyWith(attachments: updatedAttachments);
    return verifyEvidenceIfUploaded(base, photoUrl: photoUrl);
  }

  Future<Incident?> send(
    Incident incident, {
    bool strictPhoto = false,
  }) async {
    var working = incident;
    if (working.accessSecret == null || working.accessSecret!.isEmpty) {
      working = await insertDraft(working, strictPhoto: strictPhoto);
    }
    final photoUrl =
        await uploadPhotoIfPresent(working, strict: strictPhoto);
    final clientSha = working.clientEvidenceSha256 ??
        (working.attachments.isNotEmpty
            ? working.attachments.first.sha256
            : null);
    final res = await _http
        .post(
          _rpc('send_draft_report'),
          headers: _jsonHeaders(),
          body: jsonEncode({
            'p_access_secret': working.accessSecret,
            'p_photo_url': ?photoUrl,
            'p_client_sha256': ?clientSha,
          }),
        )
        .timeout(_timeout);
    if (res.statusCode >= 300) {
      throw Exception('send failed (${res.statusCode})');
    }
    final updatedAttachments = _withRemoteKey(working.attachments, photoUrl);
    final base = working.copyWith(
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

  Future<Incident> insertEmergency(Incident incident) async {
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
      'p_description': incident.description,
      'p_approx_location': landmarkLabel,
      'p_silent_mode': incident.silentMode,
      'p_latitude': ?lat,
      'p_longitude': ?lon,
      'p_accuracy_meters': ?incident.liveAccuracyMeters,
      'p_device_secret': await _deviceSecret(),
      'p_tracking_code': incident.trackingId,
      'p_access_secret': ?incident.accessSecret,
    };

    final res = await _http
        .post(
          _fn('emergency-alert'),
          headers: _jsonHeaders(),
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
    String? accessSecret,
  }) async {
    final secret = accessSecret ?? await _secretFor(trackingCode);
    if (secret == null) {
      throw Exception('live location update failed (missing secret)');
    }
    final res = await _http
        .post(
          _rpc('update_emergency_location'),
          headers: _jsonHeaders(),
          body: jsonEncode({
            'p_access_secret': secret,
            'p_latitude': latitude,
            'p_longitude': longitude,
            'p_accuracy_meters': ?accuracyMeters,
          }),
        )
        .timeout(_timeout);
    if (res.statusCode >= 300) {
      throw Exception('live location update failed (${res.statusCode})');
    }
  }

  Future<void> stopEmergencyLocation(
    String trackingCode, {
    String? accessSecret,
  }) async {
    final secret = accessSecret ?? await _secretFor(trackingCode);
    if (secret == null) {
      throw Exception('stop live location failed (missing secret)');
    }
    final res = await _http
        .post(
          _rpc('stop_emergency_location'),
          headers: _jsonHeaders(),
          body: jsonEncode({'p_access_secret': secret}),
        )
        .timeout(_timeout);
    if (res.statusCode >= 300) {
      throw Exception('stop live location failed (${res.statusCode})');
    }
  }

  Future<Incident?> submitApproachResponse(
    String trackingCode, {
    required String response,
    Incident? local,
  }) async {
    final secret = local?.accessSecret;
    if (secret == null || secret.isEmpty) {
      throw Exception('submit approach response failed (missing secret)');
    }
    final res = await _http
        .post(
          _rpc('submit_approach_response'),
          headers: _jsonHeaders(),
          body: jsonEncode({
            'p_access_secret': secret,
            'p_response': response,
          }),
        )
        .timeout(_timeout);
    if (res.statusCode >= 300) {
      throw Exception(
          'submit approach response failed (${res.statusCode}): ${res.body}');
    }
    return _fromBody(utf8.decode(res.bodyBytes), local);
  }

  Future<void> revealIdentity(
    String trackingCode, {
    required String fullName,
    required String channel,
    required String handle,
    String? safeNote,
    String? accessSecret,
  }) async {
    final secret = accessSecret ?? await _secretFor(trackingCode);
    if (secret == null) {
      throw Exception('reveal identity failed (missing secret)');
    }
    final res = await _http
        .post(
          _rpc('reveal_report_identity'),
          headers: _jsonHeaders(),
          body: jsonEncode({
            'p_access_secret': secret,
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
    final secret = local?.accessSecret;
    if (secret == null || secret.isEmpty) return local;
    final res = await _http
        .post(
          _rpc('lookup_own_report'),
          headers: _jsonHeaders(),
          body: jsonEncode({'p_access_secret': secret}),
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

  Future<String?> _secretFor(String trackingCode) async {
    // Ownership secret is persisted on the Incident, not looked up by code.
    return _deviceSecretOverride;
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
    final serverSha =
        row['evidence_sha256'] as String? ??
            row['server_sha256'] as String? ??
            local?.evidenceSha256;
    final clientSha = row['client_evidence_sha256'] as String? ??
        row['client_sha256'] as String? ??
        local?.clientEvidenceSha256 ??
        (local != null && local.attachments.isNotEmpty
            ? local.attachments.first.sha256
            : null);
    final verifiedAtUtc =
        DateTime.tryParse(row['evidence_verified_at'] as String? ?? '')
                ?.toUtc() ??
            DateTime.tryParse(row['verified_at'] as String? ?? '')?.toUtc() ??
            local?.evidenceVerifiedAtUtc;
    final integrityStatus = row['evidence_integrity_status'] as String? ??
        row['integrity_status'] as String? ??
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
    final accessSecret =
        row['access_secret'] as String? ?? local?.accessSecret;
    final trackingId = row['tracking_code'] as String;

    if (local == null) {
      final cat = IncidentCategory.fromCode(
        row['incident_type'] as String? ?? 'HRSMT',
      );
      return Incident(
        trackingId: trackingId,
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
        accessSecret: accessSecret,
      );
    }
    final nextHistory = local.status == status
        ? local.history
        : [
            ...local.history,
            StatusEvent(status: status, at: updated, actor: 'STATION'),
          ];
    return local.copyWith(
      trackingId: trackingId,
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
      accessSecret: accessSecret,
    );
  }
}
