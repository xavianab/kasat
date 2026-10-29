import 'approx_location.dart';
import 'attachment.dart';
import 'incident_category.dart';
import 'incident_priority.dart';
import 'incident_status.dart';

/// One entry in a case's audit trail. Operators can only append.
class StatusEvent {
  const StatusEvent({
    required this.status,
    required this.at,
    this.actor = 'SYSTEM',
    this.note,
  });

  final IncidentStatus status;
  final DateTime at;

  /// Station code, never a personal name.
  final String actor;
  final String? note;

  Map<String, dynamic> toJson() => {
        'status': status.code,
        'at': at.toIso8601String(),
        'actor': actor,
        'note': note,
      };

  static StatusEvent fromJson(Map<String, dynamic> json) {
    return StatusEvent(
      status: IncidentStatus.fromCode(json['status'] as String),
      at: DateTime.parse(json['at'] as String),
      actor: json['actor'] as String? ?? 'SYSTEM',
      note: json['note'] as String?,
    );
  }
}

/// What the survivor has filled in so far, before an identifier exists.
class IncidentDraft {
  const IncidentDraft({
    required this.category,
    required this.description,
    required this.priority,
    required this.countryCode,
    this.location,
    this.attachments = const [],
    this.isEmergency = false,
    this.silentMode = false,
    this.liveLatitude,
    this.liveLongitude,
    this.liveAccuracyMeters,
  });

  final IncidentCategory category;
  final String description;
  final IncidentPriority priority;

  /// ISO 3166-1 alpha-2 of the jurisdiction the survivor selected at
  /// onboarding. Carried so the operator portal can route and filter by
  /// country even while only one is live.
  final String countryCode;

  final ApproxLocation? location;
  final List<Attachment> attachments;
  final bool isEmergency;
  final bool silentMode;
  final double? liveLatitude;
  final double? liveLongitude;
  final double? liveAccuracyMeters;
}

/// A submitted report. [trackingId] is minted on the handset and is the only
/// identifier that exists — there is no user id, session id, or device id
/// anywhere in this object by design.
class Incident {
  const Incident({
    required this.trackingId,
    required this.category,
    required this.description,
    required this.priority,
    required this.status,
    required this.countryCode,
    required this.submittedAt,
    required this.updatedAt,
    required this.history,
    this.location,
    this.attachments = const [],
    this.assignedStation,
    this.isEmergency = false,
    this.silentMode = false,
    this.liveLatitude,
    this.liveLongitude,
    this.liveAccuracyMeters,
    this.locationUpdatedAt,
    this.liveLocationActive = false,
    this.officerArrivedAtUtc,
    this.approachResponseWindowSec = 90,
    this.approachResponse,
    this.approachRespondedAtUtc,
    this.identityRevealed = false,
    this.revealedName,
    this.revealedChannel,
    this.revealedHandle,
    this.evidenceSha256,
    this.clientEvidenceSha256,
    this.evidenceVerifiedAtUtc,
    this.evidenceIntegrityStatus,
    this.serverCreatedAtUtc,
    this.accessSecret,
  });

  final String trackingId;
  final IncidentCategory category;
  final String description;
  final IncidentPriority priority;
  final IncidentStatus status;

  /// ISO 3166-1 alpha-2. Set from the survivor's onboarding selection and
  /// never derived from the network or the device locale.
  final String countryCode;

  final DateTime submittedAt;
  final DateTime updatedAt;
  final List<StatusEvent> history;
  final ApproxLocation? location;
  final List<Attachment> attachments;
  final String? assignedStation;

  /// True only for reports created by the "I'm in Danger" button.
  final bool isEmergency;
  final bool silentMode;
  final double? liveLatitude;
  final double? liveLongitude;
  final double? liveAccuracyMeters;
  final DateTime? locationUpdatedAt;
  final bool liveLocationActive;

  /// Officer silent approach confirmation state.
  final DateTime? officerArrivedAtUtc;
  final int approachResponseWindowSec;

  /// `'can_come_out'` | `'abuser_present_do_not_knock'` | `'no_response'` | null
  final String? approachResponse;
  final DateTime? approachRespondedAtUtc;

  /// One-way optional self-identification state.
  final bool identityRevealed;
  final String? revealedName;
  final String? revealedChannel;
  final String? revealedHandle;

  /// Authoritative SHA-256 hex digest computed server-side from received bytes.
  final String? evidenceSha256;

  /// Handset-computed SHA-256 hex digest used only as a transport-integrity check.
  final String? clientEvidenceSha256;

  /// Server UTC timestamp when the authoritative SHA-256 was computed.
  final DateTime? evidenceVerifiedAtUtc;

  /// 'none' | 'pending_server_hash' | 'verified' | 'mismatch'
  final String? evidenceIntegrityStatus;

  final DateTime? serverCreatedAtUtc;

  /// 256-bit handset secret used to prove ownership of this report. Never
  /// shown in the UI; the short [trackingId] is display-only.
  final String? accessSecret;

  Incident copyWith({
    String? trackingId,
    IncidentStatus? status,
    DateTime? updatedAt,
    List<StatusEvent>? history,
    String? assignedStation,
    List<Attachment>? attachments,
    bool? isEmergency,
    bool? silentMode,
    double? liveLatitude,
    double? liveLongitude,
    double? liveAccuracyMeters,
    DateTime? locationUpdatedAt,
    bool? liveLocationActive,
    DateTime? officerArrivedAtUtc,
    int? approachResponseWindowSec,
    String? approachResponse,
    DateTime? approachRespondedAtUtc,
    bool? identityRevealed,
    String? revealedName,
    String? revealedChannel,
    String? revealedHandle,
    String? evidenceSha256,
    String? clientEvidenceSha256,
    DateTime? evidenceVerifiedAtUtc,
    String? evidenceIntegrityStatus,
    DateTime? serverCreatedAtUtc,
    String? accessSecret,
  }) {
    return Incident(
      trackingId: trackingId ?? this.trackingId,
      category: category,
      description: description,
      priority: priority,
      status: status ?? this.status,
      countryCode: countryCode,
      submittedAt: submittedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      history: history ?? this.history,
      location: location,
      attachments: attachments ?? this.attachments,
      assignedStation: assignedStation ?? this.assignedStation,
      isEmergency: isEmergency ?? this.isEmergency,
      silentMode: silentMode ?? this.silentMode,
      liveLatitude: liveLatitude ?? this.liveLatitude,
      liveLongitude: liveLongitude ?? this.liveLongitude,
      liveAccuracyMeters: liveAccuracyMeters ?? this.liveAccuracyMeters,
      locationUpdatedAt: locationUpdatedAt ?? this.locationUpdatedAt,
      liveLocationActive: liveLocationActive ?? this.liveLocationActive,
      officerArrivedAtUtc: officerArrivedAtUtc ?? this.officerArrivedAtUtc,
      approachResponseWindowSec:
          approachResponseWindowSec ?? this.approachResponseWindowSec,
      approachResponse: approachResponse ?? this.approachResponse,
      approachRespondedAtUtc:
          approachRespondedAtUtc ?? this.approachRespondedAtUtc,
      identityRevealed: identityRevealed ?? this.identityRevealed,
      revealedName: revealedName ?? this.revealedName,
      revealedChannel: revealedChannel ?? this.revealedChannel,
      revealedHandle: revealedHandle ?? this.revealedHandle,
      evidenceSha256: evidenceSha256 ?? this.evidenceSha256,
      clientEvidenceSha256: clientEvidenceSha256 ?? this.clientEvidenceSha256,
      evidenceVerifiedAtUtc:
          evidenceVerifiedAtUtc ?? this.evidenceVerifiedAtUtc,
      evidenceIntegrityStatus:
          evidenceIntegrityStatus ?? this.evidenceIntegrityStatus,
      serverCreatedAtUtc: serverCreatedAtUtc ?? this.serverCreatedAtUtc,
      accessSecret: accessSecret ?? this.accessSecret,
    );
  }

  Map<String, dynamic> toJson() => {
        'trackingId': trackingId,
        'category': category.code,
        'description': description,
        'priority': priority.code,
        'status': status.code,
        'countryCode': countryCode,
        'submittedAt': submittedAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'history': history.map((e) => e.toJson()).toList(),
        'location': location?.toJson(),
        'attachments': attachments.map((a) => a.toJson()).toList(),
        'assignedStation': assignedStation,
        'isEmergency': isEmergency,
        'silentMode': silentMode,
        'liveLatitude': liveLatitude,
        'liveLongitude': liveLongitude,
        'liveAccuracyMeters': liveAccuracyMeters,
        'locationUpdatedAt': locationUpdatedAt?.toIso8601String(),
        'liveLocationActive': liveLocationActive,
        'officerArrivedAtUtc': officerArrivedAtUtc?.toIso8601String(),
        'approachResponseWindowSec': approachResponseWindowSec,
        'approachResponse': approachResponse,
        'approachRespondedAtUtc': approachRespondedAtUtc?.toIso8601String(),
        'identityRevealed': identityRevealed,
        'revealedName': revealedName,
        'revealedChannel': revealedChannel,
        'revealedHandle': revealedHandle,
        'evidenceSha256': evidenceSha256,
        'clientEvidenceSha256': clientEvidenceSha256,
        'evidenceVerifiedAtUtc': evidenceVerifiedAtUtc?.toIso8601String(),
        'evidenceIntegrityStatus': evidenceIntegrityStatus,
        'serverCreatedAtUtc': serverCreatedAtUtc?.toIso8601String(),
        'accessSecret': accessSecret,
      };

  static Incident fromJson(Map<String, dynamic> json) {
    return Incident(
      trackingId: json['trackingId'] as String,
      category: IncidentCategory.fromCode(json['category'] as String),
      description: json['description'] as String,
      priority: IncidentPriority.fromCode(json['priority'] as String),
      status: IncidentStatus.fromCode(json['status'] as String),
      countryCode: json['countryCode'] as String? ?? 'ET',
      submittedAt: DateTime.parse(json['submittedAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      history: (json['history'] as List<dynamic>? ?? [])
          .map((e) => StatusEvent.fromJson(e as Map<String, dynamic>))
          .toList(),
      location: json['location'] == null
          ? null
          : ApproxLocation.fromJson(json['location'] as Map<String, dynamic>),
      attachments: (json['attachments'] as List<dynamic>? ?? [])
          .map((e) => Attachment.fromJson(e as Map<String, dynamic>))
          .toList(),
      assignedStation: json['assignedStation'] as String?,
      isEmergency: json['isEmergency'] as bool? ?? false,
      silentMode: json['silentMode'] as bool? ?? false,
      liveLatitude: (json['liveLatitude'] as num?)?.toDouble(),
      liveLongitude: (json['liveLongitude'] as num?)?.toDouble(),
      liveAccuracyMeters: (json['liveAccuracyMeters'] as num?)?.toDouble(),
      locationUpdatedAt: json['locationUpdatedAt'] == null
          ? null
          : DateTime.tryParse(json['locationUpdatedAt'] as String),
      liveLocationActive: json['liveLocationActive'] as bool? ?? false,
      officerArrivedAtUtc: json['officerArrivedAtUtc'] == null
          ? null
          : DateTime.tryParse(json['officerArrivedAtUtc'] as String),
      approachResponseWindowSec:
          (json['approachResponseWindowSec'] as num?)?.toInt() ?? 90,
      approachResponse: json['approachResponse'] as String?,
      approachRespondedAtUtc: json['approachRespondedAtUtc'] == null
          ? null
          : DateTime.tryParse(json['approachRespondedAtUtc'] as String),
      identityRevealed: json['identityRevealed'] as bool? ?? false,
      revealedName: json['revealedName'] as String?,
      revealedChannel: json['revealedChannel'] as String?,
      revealedHandle: json['revealedHandle'] as String?,
      evidenceSha256: json['evidenceSha256'] as String?,
      clientEvidenceSha256: json['clientEvidenceSha256'] as String?,
      evidenceVerifiedAtUtc: json['evidenceVerifiedAtUtc'] == null
          ? null
          : DateTime.tryParse(json['evidenceVerifiedAtUtc'] as String),
      evidenceIntegrityStatus: json['evidenceIntegrityStatus'] as String?,
      serverCreatedAtUtc: json['serverCreatedAtUtc'] == null
          ? null
          : DateTime.tryParse(json['serverCreatedAtUtc'] as String),
      accessSecret: json['accessSecret'] as String?,
    );
  }
}
