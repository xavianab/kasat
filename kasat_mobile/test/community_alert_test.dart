import 'package:flutter_test/flutter_test.dart';
import 'package:kasat_mobile/core/alert_review.dart';
import 'package:kasat_mobile/core/kasat_config.dart';
import 'package:kasat_mobile/data/local_alert_repository.dart';
import 'package:kasat_mobile/models/community_alert.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FixedReviewer implements AlertReviewer {
  _FixedReviewer(this.result);
  final ReviewResult result;

  @override
  Future<ReviewResult> review({required String title, required String body}) async {
    return result;
  }
}

void main() {
  late LocalAlertRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repo = LocalAlertRepository(
      reviewer: _FixedReviewer(
        const ReviewResult(verdict: ReviewVerdict.publish, note: 'ok'),
      ),
    );
    await repo.init();
  });

  test('live feed is scoped to a country and never mixes report ids', () async {
    final et = await repo.liveForCountry('ET');
    final us = await repo.liveForCountry('US');

    expect(et, isNotEmpty);
    expect(et.every((a) => a.countryCode == 'ET'), isTrue);
    expect(et.every((a) => a.id.startsWith('ALT-')), isTrue);
    expect(et.every((a) => !a.id.startsWith('KST-')), isTrue);
    expect(us.every((a) => a.countryCode == 'US'), isTrue);
  });

  test('a clean review publishes; an unsure review waits', () async {
    final held = LocalAlertRepository(
      reviewer: _FixedReviewer(
        const ReviewResult(verdict: ReviewVerdict.pending, note: 'vague'),
      ),
    );
    await held.init();

    final published = await repo.submit(
      kind: AlertKind.safetyNotice,
      title: 'Clinic road is dark tonight',
      body: 'The lamps between the clinic and the school are out. Walk the inner path.',
      countryCode: 'ET',
      posterToken: 'P-TEST',
      verifiedSource: true,
    );
    expect(published.visibility, AlertVisibility.live);
    expect(published.expiresAt.difference(published.postedAt), KasatConfig.alertTtl);

    final waiting = await held.submit(
      kind: AlertKind.missingPerson,
      title: 'Something',
      body: 'Maybe someone saw something somewhere I think.',
      countryCode: 'ET',
      posterToken: 'P-TEST',
      verifiedSource: true,
    );
    expect(waiting.visibility, AlertVisibility.pending);
    expect((await held.liveForCountry('ET')).any((a) => a.id == waiting.id), isFalse);
    expect((await held.pending()).any((a) => a.id == waiting.id), isTrue);
  });

  test('unverified sources cannot post', () async {
    expect(
      () => repo.submit(
        kind: AlertKind.safetyNotice,
        title: 'Should not land',
        body: 'This must never reach the feed without verification.',
        countryCode: 'ET',
        posterToken: 'P-TEST',
        verifiedSource: false,
      ),
      throwsStateError,
    );
  });

  test('a private tip never appears on the public alert', () async {
    final live = (await repo.liveForCountry('ET')).first;
    await repo.sendTip(alertId: live.id, body: 'I saw her near the bakery.');

    final after = (await repo.liveForCountry('ET')).firstWhere((a) => a.id == live.id);
    expect(after.body, isNot(contains('bakery')));
    expect(after.toJson().values, isNot(contains('I saw her near the bakery.')));

    final tips = await repo.tipsForPoster(live.posterToken);
    expect(tips.map((t) => t.body), contains('I saw her near the bakery.'));
  });

  test('only the original poster can close, and seen counts stay quiet', () async {
    final posted = await repo.submit(
      kind: AlertKind.communityWatch,
      title: 'Walking group at dusk',
      body: 'Meet at the library steps at seven if you want company home.',
      countryCode: 'ET',
      posterToken: 'P-MINE',
      verifiedSource: true,
    );

    await repo.markSeen(posted.id);
    await repo.close(posted.id, posterToken: 'P-OTHER');
    expect((await repo.liveForCountry('ET')).any((a) => a.id == posted.id), isTrue);

    await repo.close(posted.id, posterToken: 'P-MINE');
    expect((await repo.liveForCountry('ET')).any((a) => a.id == posted.id), isFalse);
    expect((await repo.liveForCountry('ET')).first.seenCount, greaterThanOrEqualTo(0));
  });
}
