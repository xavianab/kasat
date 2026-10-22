import 'package:flutter_test/flutter_test.dart';
import 'package:kasat_mobile/data/local_incident_repository.dart';
import 'package:kasat_mobile/models/incident.dart';
import 'package:kasat_mobile/models/incident_category.dart';
import 'package:kasat_mobile/models/incident_priority.dart';
import 'package:kasat_mobile/models/incident_status.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late LocalIncidentRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repo = LocalIncidentRepository();
    await repo.init();
  });

  IncidentDraft draft() => const IncidentDraft(
        category: IncidentCategory.harassment,
        description: 'A long enough description of what happened to me last week at work.',
        priority: IncidentPriority.medium,
        countryCode: 'ET',
      );

  test('offline submit is queued, not sent', () async {
    final incident = await repo.submit(draft(), trackingId: 'KST-QTEST', offline: true);
    expect(incident.status, IncidentStatus.queued);
    expect(await repo.queuedCount(), greaterThan(0));
  });

  test('flushQueued sends waiting reports', () async {
    await repo.submit(draft(), trackingId: 'KST-FLUSH', offline: true);
    final n = await repo.flushQueued();
    expect(n, greaterThan(0));
    expect((await repo.lookup('KST-FLUSH'))?.status, IncidentStatus.sent);
    expect(await repo.queuedCount(), 0);
  });
}
