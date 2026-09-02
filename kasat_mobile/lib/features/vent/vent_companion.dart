import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../../core/kasat_config.dart';
import 'vent_identities.dart';
import 'vent_models.dart';
import 'vent_repository.dart';

/// One companion message per Vent post, a few seconds after it is created.
///
/// Failures are silent. A missing key, a timeout, or a bad reply simply means
/// this post has no Kasat 🌸 message — never an error on her screen.
class VentCompanion {
  VentCompanion({http.Client? client, String? apiKey})
      : _client = client ?? http.Client(),
        _apiKey = apiKey ?? KasatConfig.anthropicApiKey;

  final http.Client _client;
  final String _apiKey;
  static const _uuid = Uuid();

  static const _system = '''
You are Kasat, a quiet companion on a private board where people write what
they cannot say out loud. You are not a therapist, not a crisis line, and not
a doctor.

Write like a caring friend texting back. Two to four short sentences.
Do not say you are sorry to hear that. Do not diagnose. Do not give
instructions unless the writer asked for them. Do not use the words
"as an AI" or "language model". Do not ask a list of clinical questions.
Acknowledge what they wrote. Leave the door open. That is enough.
''';

  Future<void> maybeReply({
    required VentRepository vents,
    required VentPost post,
  }) async {
    if (post.aiCompanionPosted || _apiKey.isEmpty) return;

    try {
      final response = await _client
          .post(
            Uri.parse('https://api.anthropic.com/v1/messages'),
            headers: {
              'content-type': 'application/json',
              'x-api-key': _apiKey,
              'anthropic-version': '2023-06-01',
            },
            body: jsonEncode({
              'model': KasatConfig.anthropicModel,
              'max_tokens': 220,
              'system': _system,
              'messages': [
                {'role': 'user', 'content': post.body},
              ],
            }),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode < 200 || response.statusCode >= 300) return;
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final content = decoded['content'] as List<dynamic>?;
      if (content == null || content.isEmpty) return;
      final text = (content.first as Map<String, dynamic>)['text'] as String?;
      final body = text?.trim();
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
