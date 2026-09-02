import '../models/community_alert.dart';

/// Isolated from [IncidentRepository]. A future backend must keep these
/// tables, buckets, and realtime channels apart.
abstract interface class AlertRepository {
  Future<List<CommunityAlert>> liveForCountry(String countryCode);

  Future<List<CommunityAlert>> pending();

  Stream<void> watch();

  Future<CommunityAlert> submit({
    required AlertKind kind,
    required String title,
    required String body,
    required String countryCode,
    required String posterToken,
    required bool verifiedSource,
  });

  Future<void> markSeen(String alertId);

  Future<void> close(String alertId, {required String posterToken});

  Future<void> sendTip({required String alertId, required String body});

  /// Tips addressed to [posterToken]. Never shown on the public feed.
  Future<List<AlertTip>> tipsForPoster(String posterToken);
}
