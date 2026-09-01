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

  Incident copyWith({
    IncidentStatus? status,
    DateTime? updatedAt,
    List<StatusEvent>? history,
    String? assignedStation,
  }) {
    return Incident(
      trackingId: trackingId,
      category: category,
      description: description,
      priority: priority,
      status: status ?? this.status,
      countryCode: countryCode,
      submittedAt: submittedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      history: history ?? this.history,
      location: location,
      attachments: attachments,
      assignedStation: assignedStation ?? this.assignedStation,
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
    );
  }
}
