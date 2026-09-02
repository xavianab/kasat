/// Community Alerts are a separate domain from incident reports.
///
/// Identifiers here use the `ALT-` prefix and never share a field, table, or
/// id space with `Incident.trackingId`. A tip on an alert cannot be joined
/// to a report.
enum AlertKind {
  missingPerson(code: 'MISSING', label: 'Missing person'),
  safetyNotice(code: 'NOTICE', label: 'Safety notice'),
  communityWatch(code: 'WATCH', label: 'Community watch');

  const AlertKind({required this.code, required this.label});

  final String code;
  final String label;

  static AlertKind fromCode(String code) => AlertKind.values.firstWhere(
        (k) => k.code == code,
        orElse: () => AlertKind.safetyNotice,
      );
}

enum AlertVisibility {
  /// Live on the feed.
  live,

  /// Waiting for a person. The first-pass model was unsure or unavailable.
  pending,

  /// Closed by the original poster, or past its expiry.
  closed,
}

class CommunityAlert {
  const CommunityAlert({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.countryCode,
    required this.postedAt,
    required this.expiresAt,
    required this.visibility,
    required this.verifiedSource,
    required this.posterToken,
    this.seenCount = 0,
    this.reviewNote,
  });

  /// `ALT-XXXXX`. Never a `KST-` tracking id.
  final String id;
  final AlertKind kind;
  final String title;
  final String body;
  final String countryCode;
  final DateTime postedAt;
  final DateTime expiresAt;
  final AlertVisibility visibility;
  final bool verifiedSource;

  /// Local-only handle so the original poster can close their own alert.
  /// Not a user id and not stored on reports.
  final String posterToken;
  final int seenCount;
  final String? reviewNote;

  bool get expired => DateTime.now().isAfter(expiresAt);

  bool get isLive => visibility == AlertVisibility.live && !expired;

  CommunityAlert copyWith({
    AlertVisibility? visibility,
    int? seenCount,
    String? reviewNote,
  }) {
    return CommunityAlert(
      id: id,
      kind: kind,
      title: title,
      body: body,
      countryCode: countryCode,
      postedAt: postedAt,
      expiresAt: expiresAt,
      visibility: visibility ?? this.visibility,
      verifiedSource: verifiedSource,
      posterToken: posterToken,
      seenCount: seenCount ?? this.seenCount,
      reviewNote: reviewNote ?? this.reviewNote,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.code,
        'title': title,
        'body': body,
        'countryCode': countryCode,
        'postedAt': postedAt.toIso8601String(),
        'expiresAt': expiresAt.toIso8601String(),
        'visibility': visibility.name,
        'verifiedSource': verifiedSource,
        'posterToken': posterToken,
        'seenCount': seenCount,
        'reviewNote': reviewNote,
      };

  static CommunityAlert fromJson(Map<String, dynamic> json) {
    return CommunityAlert(
      id: json['id'] as String,
      kind: AlertKind.fromCode(json['kind'] as String),
      title: json['title'] as String,
      body: json['body'] as String,
      countryCode: json['countryCode'] as String,
      postedAt: DateTime.parse(json['postedAt'] as String),
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      visibility: AlertVisibility.values.firstWhere(
        (v) => v.name == json['visibility'],
        orElse: () => AlertVisibility.pending,
      ),
      verifiedSource: json['verifiedSource'] as bool? ?? false,
      posterToken: json['posterToken'] as String,
      seenCount: json['seenCount'] as int? ?? 0,
      reviewNote: json['reviewNote'] as String?,
    );
  }
}

/// A private note to the original poster. Never rendered on the feed.
class AlertTip {
  const AlertTip({
    required this.id,
    required this.alertId,
    required this.body,
    required this.sentAt,
  });

  final String id;
  final String alertId;
  final String body;
  final DateTime sentAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'alertId': alertId,
        'body': body,
        'sentAt': sentAt.toIso8601String(),
      };

  static AlertTip fromJson(Map<String, dynamic> json) {
    return AlertTip(
      id: json['id'] as String,
      alertId: json['alertId'] as String,
      body: json['body'] as String,
      sentAt: DateTime.parse(json['sentAt'] as String),
    );
  }
}
