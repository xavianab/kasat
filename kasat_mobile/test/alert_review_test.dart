import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kasat_mobile/core/alert_id.dart';
import 'package:kasat_mobile/core/alert_review.dart';
import 'package:kasat_mobile/core/tracking_id.dart';
import 'package:kasat_mobile/data/local_alert_repository.dart';
import 'package:kasat_mobile/models/community_alert.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AlertId', () {
    test('never looks like a report tracking id', () {
      for (var i = 0; i < 200; i++) {
        final id = AlertId.generate();
        expect(AlertId.isValid(id), isTrue);
        expect(id.startsWith('KST-'), isFalse);
        expect(TrackingId.isValid(id), isFalse);
      }
    });
  });

  group('aiProxyCallerId', () {
    test('derives a stable hex digest and never equals the raw secret', () {
      const secret = 'abcdefghijklmnopqrstuvwxyz0123456789ABCD';
      final a = aiProxyCallerId(secret);
      final b = aiProxyCallerId(secret);
      expect(a, b);
      expect(a.length, 64);
      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(a), isTrue);
      expect(a, isNot(equals(secret)));
      expect(a.contains(secret), isFalse);
      expect(
        aiProxyCallerId('other-secret-at-least-thirty-two-chars!!'),
        isNot(equals(a)),
      );
    });
  });

  group('parseReviewJson', () {
    test('publishes a clean reply', () {
      final result = parseReviewJson('{"verdict":"publish","note":"Clear and specific."}');
      expect(result.verdict, ReviewVerdict.publish);
      expect(result.note, 'Clear and specific.');
    });

    test('holds an uncertain or abusive draft', () {
      final result = parseReviewJson('''
```json
{"verdict":"pending","note":"Contradicts itself."}
```
''');
      expect(result.verdict, ReviewVerdict.pending);
    });

    test('holds unreadable output rather than publishing it', () {
      final result = parseReviewJson('sure this is fine');
      expect(result.verdict, ReviewVerdict.pending);
    });
  });

  test('a missing review proxy holds the post for a person', () async {
    final reviewer = AnthropicAlertReviewer();
    final result = await reviewer.review(title: 'Test', body: 'A complete sentence.');
    expect(result.verdict, ReviewVerdict.pending);
  });

  group('AnthropicAlertReviewer failure paths', () {
    const caller = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

    test('401 unauthorized holds for a person without throwing', () async {
      final client = MockClient((request) async {
        expect(request.headers['x-kasat-proxy-secret'], 'proxy-secret-at-least-thirty-two-chars');
        expect(jsonDecode(request.body)['caller_id'], caller);
        return http.Response('{"error":"unauthorized"}', 401);
      });
      final reviewer = AnthropicAlertReviewer(
        client: client,
        supabaseUrl: 'https://example.supabase.co',
        supabaseAnonKey: 'anon-key',
        proxySecret: 'proxy-secret-at-least-thirty-two-chars',
        callerIdProvider: () => caller,
      );
      final result = await reviewer.review(title: 'Title', body: 'Body text that is long enough.');
      expect(result.verdict, ReviewVerdict.pending);
      expect(result.note, contains('Held for a person'));
    });

    test('network failure holds for a person without throwing', () async {
      final client = MockClient((request) async {
        throw http.ClientException('unreachable');
      });
      final reviewer = AnthropicAlertReviewer(
        client: client,
        supabaseUrl: 'https://example.supabase.co',
        supabaseAnonKey: 'anon-key',
        proxySecret: 'proxy-secret-at-least-thirty-two-chars',
        callerIdProvider: () => caller,
      );
      final result = await reviewer.review(title: 'Title', body: 'Body text that is long enough.');
      expect(result.verdict, ReviewVerdict.pending);
      expect(result.note, contains('could not be reached'));
    });

    test('429 rate limit holds for a person without throwing', () async {
      final client = MockClient((request) async {
        return http.Response(
          '{"error":"rate_limit_exceeded","reason":"caller_cap"}',
          429,
        );
      });
      final reviewer = AnthropicAlertReviewer(
        client: client,
        supabaseUrl: 'https://example.supabase.co',
        supabaseAnonKey: 'anon-key',
        proxySecret: 'proxy-secret-at-least-thirty-two-chars',
        callerIdProvider: () => caller,
      );
      final result = await reviewer.review(title: 'Title', body: 'Body text that is long enough.');
      expect(result.verdict, ReviewVerdict.pending);
      expect(result.note, contains('Held for a person'));
    });
  });

  test('submit keeps the draft as pending when review is rejected', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = LocalAlertRepository(
      reviewer: AnthropicAlertReviewer(
        client: MockClient((_) async => http.Response('{"error":"unauthorized"}', 401)),
        supabaseUrl: 'https://example.supabase.co',
        supabaseAnonKey: 'anon-key',
        proxySecret: 'proxy-secret-at-least-thirty-two-chars',
        callerIdProvider: () =>
            'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      ),
      callerIdProvider: () =>
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
    );
    await repo.init();

    final alert = await repo.submit(
      kind: AlertKind.safetyNotice,
      title: 'Neighbourhood watch',
      body: 'A coherent report with who where and when details for review.',
      countryCode: 'ET',
      posterToken: 'P-testtoken',
      verifiedSource: true,
    );

    expect(alert.visibility, AlertVisibility.pending);
    expect(alert.title, 'Neighbourhood watch');
    expect(alert.body, contains('coherent report'));
    final pending = await repo.pending();
    expect(pending.any((a) => a.id == alert.id), isTrue);
  });
}
