import 'dart:convert';

import 'package:http/http.dart' as http;

import 'kasat_config.dart';

enum ReviewVerdict { publish, pending }

class ReviewResult {
  const ReviewResult({required this.verdict, required this.note});

  final ReviewVerdict verdict;
  final String note;
}

/// First-pass filter for a community alert.
///
/// This is not a fact checker. It cannot confirm a person is missing. It can
/// only catch incoherent, contradictory, or obviously abusive drafts before a
/// person has to look at them.
abstract interface class AlertReviewer {
  Future<ReviewResult> review({required String title, required String body});
}

/// Sends the draft to Claude. If the key is missing or the call fails, the
/// post sits in the pending queue rather than going live.
class AnthropicAlertReviewer implements AlertReviewer {
  AnthropicAlertReviewer({http.Client? client, String? apiKey})
      : _client = client ?? http.Client(),
        _apiKey = apiKey ?? KasatConfig.anthropicApiKey;

  final http.Client _client;
  final String _apiKey;

  static const _system = '''
You are a first-pass safety filter for a community alert board.
You are NOT a fact checker. You cannot confirm whether an event happened.
Decide only whether the text is coherent enough for a human moderator to
read, or whether it should wait in a pending queue.

Send to pending if any of these are true:
- the details contradict each other
- the text is too vague to act on (no who/where/when of any kind)
- it looks like spam, advertising, or a copy-paste scam
- it contains harassment, slurs, or threats toward a named person
- it asks people to pay money or click a link

Otherwise verdict is publish.

Reply with JSON only: {"verdict":"publish"|"pending","note":"short reason"}
''';

  @override
  Future<ReviewResult> review({required String title, required String body}) async {
    if (_apiKey.isEmpty) {
      return const ReviewResult(
        verdict: ReviewVerdict.pending,
        note: 'Review service is not configured. Held for a person.',
      );
    }

    try {
      final response = await _client.post(
        Uri.parse('https://api.anthropic.com/v1/messages'),
        headers: {
          'content-type': 'application/json',
          'x-api-key': _apiKey,
          'anthropic-version': '2023-06-01',
        },
        body: jsonEncode({
          'model': KasatConfig.anthropicModel,
          'max_tokens': 200,
          'system': _system,
          'messages': [
            {
              'role': 'user',
              'content': 'Title: $title\n\nBody: $body',
            },
          ],
        }),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const ReviewResult(
          verdict: ReviewVerdict.pending,
          note: 'Review service did not answer. Held for a person.',
        );
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final content = decoded['content'] as List<dynamic>?;
      final text = content?.isNotEmpty == true
          ? (content!.first as Map<String, dynamic>)['text'] as String? ?? ''
          : '';
      return parseReviewJson(text);
    } catch (_) {
      return const ReviewResult(
        verdict: ReviewVerdict.pending,
        note: 'Review service could not be reached. Held for a person.',
      );
    }
  }
}

/// Parses the model's JSON even if it wrapped it in a fence.
ReviewResult parseReviewJson(String raw) {
  final start = raw.indexOf('{');
  final end = raw.lastIndexOf('}');
  if (start < 0 || end <= start) {
    return const ReviewResult(
      verdict: ReviewVerdict.pending,
      note: 'Review reply was unreadable. Held for a person.',
    );
  }

  try {
    final map = jsonDecode(raw.substring(start, end + 1)) as Map<String, dynamic>;
    final verdict = map['verdict'] == 'publish'
        ? ReviewVerdict.publish
        : ReviewVerdict.pending;
    final note = (map['note'] as String?)?.trim();
    return ReviewResult(
      verdict: verdict,
      note: (note == null || note.isEmpty) ? 'Reviewed.' : note,
    );
  } catch (_) {
    return const ReviewResult(
      verdict: ReviewVerdict.pending,
      note: 'Review reply was unreadable. Held for a person.',
    );
  }
}
