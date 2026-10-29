import 'vent_identities.dart';

class VentPost {
  const VentPost({
    required this.id,
    required this.displayIdentity,
    required this.body,
    required this.createdAt,
    required this.expiresAt,
    required this.authorToken,
    this.replyCount = 0,
    this.supportCount = 0,
    this.aiCompanionPosted = false,
  });

  final String id;
  final String displayIdentity;
  final String body;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String authorToken;
  final int replyCount;
  final int supportCount;
  final bool aiCompanionPosted;

  Duration get remaining => expiresAt.difference(DateTime.now());

  bool get expired => remaining.isNegative;

  VentPost copyWith({
    int? replyCount,
    int? supportCount,
    bool? aiCompanionPosted,
  }) {
    return VentPost(
      id: id,
      displayIdentity: displayIdentity,
      body: body,
      createdAt: createdAt,
      expiresAt: expiresAt,
      authorToken: authorToken,
      replyCount: replyCount ?? this.replyCount,
      supportCount: supportCount ?? this.supportCount,
      aiCompanionPosted: aiCompanionPosted ?? this.aiCompanionPosted,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'displayIdentity': displayIdentity,
        'body': body,
        'createdAt': createdAt.toIso8601String(),
        'expiresAt': expiresAt.toIso8601String(),
        'authorToken': authorToken,
        'replyCount': replyCount,
        'supportCount': supportCount,
        'aiCompanionPosted': aiCompanionPosted,
      };

  static VentPost fromJson(Map<String, dynamic> json) {
    return VentPost(
      id: json['id'] as String,
      displayIdentity: json['displayIdentity'] as String,
      body: json['body'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      authorToken: json['authorToken'] as String,
      replyCount: json['replyCount'] as int? ?? 0,
      supportCount: json['supportCount'] as int? ?? 0,
      aiCompanionPosted: json['aiCompanionPosted'] as bool? ?? false,
    );
  }
}

class VentReply {
  const VentReply({
    required this.id,
    required this.postId,
    required this.fromDisplayIdentity,
    required this.body,
    required this.createdAt,
    required this.isSupportTap,
    this.isAiCompanion = false,
  });

  final String id;
  final String postId;
  final String fromDisplayIdentity;
  final String body;
  final DateTime createdAt;
  final bool isSupportTap;
  final bool isAiCompanion;

  bool get isKasatCompanion =>
      isAiCompanion || fromDisplayIdentity == kasatCompanionIdentity;

  Map<String, dynamic> toJson() => {
        'id': id,
        'postId': postId,
        'fromDisplayIdentity': fromDisplayIdentity,
        'body': body,
        'createdAt': createdAt.toIso8601String(),
        'isSupportTap': isSupportTap,
        'isAiCompanion': isAiCompanion,
      };

  static VentReply fromJson(Map<String, dynamic> json) {
    return VentReply(
      id: json['id'] as String,
      postId: json['postId'] as String,
      fromDisplayIdentity: json['fromDisplayIdentity'] as String,
      body: json['body'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      isSupportTap: json['isSupportTap'] as bool? ?? false,
      isAiCompanion: json['isAiCompanion'] as bool? ?? false,
    );
  }
}
