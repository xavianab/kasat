import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../../core/kasat_config.dart';
import 'vent_identities.dart';
import 'vent_models.dart';
import 'vent_repository.dart';

/// One companion message per Vent post, a few seconds after it is created.
///
/// Failures are silent. A missing backend, a timeout, or a bad reply simply
/// means this post has no Kasat 🌸 message — never an error on her screen.
class VentCompanion {
  VentCompanion({http.Client? client, String? supabaseUrl, String? supabaseAnonKey})
      : _client = client ?? http.Client(),
        _supabaseUrl = supabaseUrl ?? KasatConfig.supabaseUrl,
        _supabaseAnonKey = supabaseAnonKey ?? KasatConfig.supabaseAnonKey;

  final http.Client _client;
  final String _supabaseUrl;
  final String _supabaseAnonKey;
  static const _uuid = Uuid();

  Future<void> maybeReply({
    required VentRepository vents,
    required VentPost post,
  }) async {
    if (post.aiCompanionPosted) return;
    if (_supabaseUrl.isEmpty || _supabaseAnonKey.isEmpty) return;

    try {
      final response = await _client
          .post(
            Uri.parse('$_supabaseUrl/functions/v1/ai-proxy'),
            headers: {
              'content-type': 'application/json',
              'apikey': _supabaseAnonKey,
              'Authorization': 'Bearer $_supabaseAnonKey',
            },
            body: jsonEncode({
              'kind': 'vent',
              'body': post.body,
            }),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode < 200 || response.statusCode >= 300) return;
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final body = (decoded['text'] as String?)?.trim();
      if (body == null || body.isEmpty) return;

      await vents.addCompanionReply(
        VentReply(
          id: _uuid.v4(),
          postId: post.id,
          fromDisplayIdentity: kasatCompanionIdentity,
          body: body,
          createdAt: DateTime.now(),
          isSupportTap: false,
          isAiCompanion: true,
        ),
      );
    } catch (_) {
      // Silent skip — a companion message is a gift, not a requirement.
    }
  }
}
