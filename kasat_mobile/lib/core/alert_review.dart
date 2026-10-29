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

/// Sends the draft through the Kasat `ai-proxy` Edge Function. The Anthropic
/// key never leaves the server. If the proxy is missing or the call fails, the
/// post sits in the pending queue rather than going live.
class AnthropicAlertReviewer implements AlertReviewer {
  AnthropicAlertReviewer({
    http.Client? client,
    String? supabaseUrl,
    String? supabaseAnonKey,
  })  : _client = client ?? http.Client(),
        _supabaseUrl = supabaseUrl ?? KasatConfig.supabaseUrl,
        _supabaseAnonKey = supabaseAnonKey ?? KasatConfig.supabaseAnonKey;

  final http.Client _client;
  final String _supabaseUrl;
  final String _supabaseAnonKey;

  @override
  Future<ReviewResult> review({required String title, required String body}) async {
    if (_supabaseUrl.isEmpty || _supabaseAnonKey.isEmpty) {
      return const ReviewResult(
        verdict: ReviewVerdict.pending,
        note: 'Review service is not configured. Held for a person.',
      );
    }

    try {
      final response = await _client.post(
        Uri.parse('$_supabaseUrl/functions/v1/ai-proxy'),
        headers: {
          'content-type': 'application/json',
          'apikey': _supabaseAnonKey,
          'Authorization': 'Bearer $_supabaseAnonKey',
        },
        body: jsonEncode({
          'kind': 'review',
          'title': title,
          'body': body,
        }),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const ReviewResult(
          verdict: ReviewVerdict.pending,
          note: 'Review service did not answer. Held for a person.',
        );
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final verdict = decoded['verdict'] == 'publish'
          ? ReviewVerdict.publish
          : ReviewVerdict.pending;
      final note = (decoded['note'] as String?)?.trim();
      return ReviewResult(
        verdict: verdict,
        note: (note == null || note.isEmpty) ? 'Reviewed.' : note,
      );
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
