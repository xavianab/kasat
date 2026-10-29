import '../models/incident.dart';

/// A notification that has been cleared for display on a lock screen.
///
/// There is no public constructor that takes arbitrary text. The only way to
/// obtain one is through [NotificationPolicy], which is what makes "generic
/// text only" a property of the type rather than a rule someone has to
/// remember.
class SafeNotification {
  const SafeNotification._(this.title, this.body);

  final String title;
  final String body;

  @override
  String toString() => 'SafeNotification($title / $body)';
}

/// The single chokepoint for anything Kasat is allowed to put on a lock screen.
///
/// A notification preview is the most common way this app gets someone hurt:
/// it renders on a locked handset, in front of whoever is holding it. So the
/// policy is not "keep notifications vague" — it is that case content never
/// reaches the notification layer at all. Every method here discards its input
/// and returns fixed copy.
abstract final class NotificationPolicy {
  /// Approved strings. Neither mentions the app, a case, or a status.
  static const _title = 'You have an update';
  static const _body = 'You have an update.';

  /// Tokens that must never appear in outgoing notification text. Used by
  /// [leaksSensitiveContent] and by the test suite.
  static const forbiddenTokens = <String>[
    'kasat',
    'incident',
    'report',
    'case',
    'police',
    'assault',
    'harassment',
    'trafficking',
    'investigation',
    'survivor',
    'evidence',
  ];

  /// A status change on a case. The incident is accepted so callers do not
  /// have to strip it themselves — and then deliberately ignored.
  static SafeNotification forStatusChange(Incident incident) {
    return const SafeNotification._(_title, _body);
  }

  /// Anything else. Same output; the parameter exists only so a caller with a
  /// payload in hand has somewhere to put it.
  static SafeNotification forPayload(Object? payload) {
    return const SafeNotification._(_title, _body);
  }

  /// True if [text] contains a case identifier or any forbidden token.
  ///
  /// Nothing in the app needs this to build a notification — it exists so the
  /// tests, and a future push handler dealing with server-supplied strings,
  /// can assert on the guarantee instead of trusting it.
  static bool leaksSensitiveContent(String text) {
    final lower = text.toLowerCase();
    if (RegExp(r'kst-[a-z0-9]{5}', caseSensitive: false).hasMatch(text)) return true;
    return forbiddenTokens.any(lower.contains);
  }
}

/// Implemented by whatever eventually talks to APNs or FCM.
///
/// Typed against [SafeNotification] so a transport physically cannot be handed
/// case content to deliver.
abstract interface class NotificationTransport {
  Future<void> deliver(SafeNotification notification);
}
