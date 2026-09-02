import 'vent_models.dart';

/// Isolated from reports and community alerts. A future backend must keep
/// Vent Here in its own table — no join to identity or incident rows.
abstract interface class VentRepository {
  Future<List<VentPost>> liveFeed();

  Stream<void> watch();

  Future<VentPost> createPost({
    required String body,
    required String authorToken,
  });

  Future<VentReply> reply({
    required String postId,
    required String fromAuthorToken,
    required String body,
  });

  Future<void> support({
    required String postId,
    required String fromAuthorToken,
  });

  /// Private text replies, plus the AI companion message. Only the original
  /// poster may read these. Other repliers never see them.
  Future<List<VentReply>> privateRepliesForPoster({
    required String postId,
    required String authorToken,
  });

  Future<void> markAiCompanionPosted(String postId);

  Future<void> addCompanionReply(VentReply reply);

  /// Hard-deletes expired posts and every reply under them. Unrecoverable.
  Future<int> purgeExpired();
}
