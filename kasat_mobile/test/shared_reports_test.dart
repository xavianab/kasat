import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kasat_mobile/core/kasat_config.dart';
import 'package:kasat_mobile/core/notification_policy.dart';
import 'package:kasat_mobile/data/local_incident_repository.dart';
import 'package:kasat_mobile/data/remote_reports_client.dart';
import 'package:kasat_mobile/models/incident.dart';
import 'package:kasat_mobile/models/incident_category.dart';
import 'package:kasat_mobile/models/incident_priority.dart';
import 'package:kasat_mobile/models/incident_status.dart';
import 'package:shared_preferences/shared_preferences.dart';

IncidentDraft draft() => const IncidentDraft(
      category: IncidentCategory.harassment,
      description:
          'A long enough description of what happened to me last week at work near the market.',
      priority: IncidentPriority.medium,
      countryCode: 'ET',
    );

void main() {
  test('reports save as draft and Send to police marks them sent', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = LocalIncidentRepository();
    await repo.init();

    final saved = await repo.submit(draft(), trackingId: 'KST-2H7KQ');
    expect(saved.status, IncidentStatus.draft);

    final sent = await repo.sendToPolice('KST-2H7KQ');
    expect(sent?.status, IncidentStatus.sent);
  });

  test('survivor status changes are never pushed to the lock screen', () {
    expect(KasatConfig.survivorStatusPush, isFalse);
    final notification = NotificationPolicy.forStatusChange(
      Incident(
        trackingId: 'KST-2H7KQ',
        category: IncidentCategory.harassment,
        description: 'A long enough description of what happened to me last week at work.',
        priority: IncidentPriority.medium,
        status: IncidentStatus.underReview,
        countryCode: 'ET',
        submittedAt: DateTime(2026, 10, 19),
        updatedAt: DateTime(2026, 10, 19),
        history: const [],
      ),
    );
    expect(notification.body.toLowerCase(), isNot(contains('report')));
    expect(notification.body.toLowerCase(), isNot(contains('kasat')));
    expect(NotificationPolicy.leaksSensitiveContent('${notification.title} ${notification.body}'),
        isFalse);
  });

  test('remote client posts a draft then sends without leaking identity fields', () async {
    final bodies = <String>[];
    final client = RemoteReportsClient(
      supabaseUrl: 'https://example.supabase.co',
      supabaseAnonKey: 'test-anon-key',
      httpClient: MockClient((request) async {
        bodies.add(request.body);
        expect(request.body, isNot(contains('"phone"')));
        expect(request.body, isNot(contains('device_id')));
        expect(request.body, isNot(contains('ip_address')));
        expect(request.body, isNot(contains('"name"')));
        const secret = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
        if (request.url.path.endsWith('/rpc/create_draft_report')) {
          return http.Response(
            '{"tracking_code":"KST-2H7KQ","access_secret":"$secret","incident_type":"HRSMT","approx_location":null,"description":"${draft().description}","photo_url":null,"status":"draft","sent_at":null,"created_at":"2026-10-19T00:00:00Z"}',
            200,
          );
        }
        return http.Response(
          '{"tracking_code":"KST-2H7KQ","access_secret":"$secret","incident_type":"HRSMT","approx_location":null,"description":"${draft().description}","photo_url":null,"status":"sent","sent_at":"2026-10-19T00:01:00Z","created_at":"2026-10-19T00:00:00Z"}',
          200,
        );
      }),
    );

    final incident = Incident(
      trackingId: 'KST-2H7KQ',
      category: IncidentCategory.harassment,
      description: draft().description,
      priority: IncidentPriority.medium,
      status: IncidentStatus.draft,
      countryCode: 'ET',
      submittedAt: DateTime(2026, 10, 19),
      updatedAt: DateTime(2026, 10, 19),
      history: const [],
    );

    await client.insertDraft(incident);
    final sent = await client.send(incident);
    expect(sent?.status, IncidentStatus.sent);
    expect(bodies, isNotEmpty);
  });

  test('lookup maps under_review from the shared table', () async {
    final client = RemoteReportsClient(
      supabaseUrl: 'https://example.supabase.co',
      supabaseAnonKey: 'test-anon-key',
      httpClient: MockClient((request) async {
        return http.Response(
          '{"id":"r1","tracking_code":"KST-2H7KQ","incident_type":"HRSMT","approx_location":null,"description":"desc","photo_url":null,"status":"under_review","sent_at":"2026-10-19T00:01:00Z","created_at":"2026-10-19T00:00:00Z"}',
          200,
        );
      }),
    );
    final local = Incident(
      trackingId: 'KST-2H7KQ',
      category: IncidentCategory.harassment,
      description: draft().description,
      priority: IncidentPriority.medium,
      status: IncidentStatus.sent,
      countryCode: 'ET',
      submittedAt: DateTime(2026, 10, 19),
      updatedAt: DateTime(2026, 10, 19),
      history: const [],
      accessSecret:
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    );
    final remote = await client.lookup('KST-2H7KQ', local);
    expect(remote?.status, IncidentStatus.underReview);
  });
}
