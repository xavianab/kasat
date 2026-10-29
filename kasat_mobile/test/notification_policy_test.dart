import 'package:flutter_test/flutter_test.dart';
import 'package:kasat_mobile/core/kasat_config.dart';
import 'package:kasat_mobile/core/notification_policy.dart';
import 'package:kasat_mobile/models/approx_location.dart';
import 'package:kasat_mobile/models/incident.dart';
import 'package:kasat_mobile/models/incident_category.dart';
import 'package:kasat_mobile/models/incident_priority.dart';
import 'package:kasat_mobile/models/incident_status.dart';

/// A notification preview renders on a locked handset, in front of whoever is
/// holding it. These tests are the enforcement of "generic text only" — they
/// feed the policy the most sensitive incident that can exist and assert that
/// none of it survives.
void main() {
  final incident = Incident(
    trackingId: 'KST-8X9P2',
    category: IncidentCategory.trafficking,
    description: 'He said he would kill me if I told the police anything.',
    priority: IncidentPriority.critical,
    status: IncidentStatus.underReview,
    countryCode: 'ET',
    submittedAt: DateTime(2026, 3, 4, 21, 15),
    updatedAt: DateTime(2026, 3, 4, 22, 30),
    history: const [],
    attachments: const [],
    location: ApproxLocation.snapped(
      latitude: 9.0108,
      longitude: 38.7613,
      precision: LocationPrecision.district,
    ),
    assignedStation: 'STN-04',
  );

  group('NotificationPolicy', () {
    test('does not push police status changes to her phone', () {
      expect(KasatConfig.survivorStatusPush, isFalse);
    });

    test('emits the same generic copy for a status change', () {
      final notification = NotificationPolicy.forStatusChange(incident);

      expect(notification.title, 'You have an update');
      expect(notification.body, 'You have an update.');
    });

    test('leaks no part of the incident it was handed', () {
      final notification = NotificationPolicy.forStatusChange(incident);
      final rendered = '${notification.title} ${notification.body}';

      expect(rendered, isNot(contains(incident.trackingId)));
      expect(rendered.toLowerCase(), isNot(contains('trafficking')));
      expect(rendered.toLowerCase(), isNot(contains('kill')));
      expect(rendered, isNot(contains('STN-04')));
      expect(rendered.toLowerCase(), isNot(contains('kasat')));
      expect(NotificationPolicy.leaksSensitiveContent(rendered), isFalse);
    });

    test('never names the app on a lock screen', () {
      for (final text in [
        NotificationPolicy.forStatusChange(incident).title,
        NotificationPolicy.forStatusChange(incident).body,
        NotificationPolicy.forPayload({'trackingId': 'KST-8X9P2'}).title,
        NotificationPolicy.forPayload(null).body,
      ]) {
        expect(text.toLowerCase(), isNot(contains('kasat')));
      }
    });

    test('discards an arbitrary payload rather than forwarding it', () {
      final notification = NotificationPolicy.forPayload({
        'trackingId': 'KST-8X9P2',
        'body': 'Your assault report was updated by Addis police',
      });

      expect(notification.title, 'You have an update');
      expect(notification.body, 'You have an update.');
    });

    group('leaksSensitiveContent', () {
      test('catches a tracking code in any case', () {
        expect(NotificationPolicy.leaksSensitiveContent('Update on KST-8X9P2'),
            isTrue);
        expect(NotificationPolicy.leaksSensitiveContent('update on kst-8x9p2'),
            isTrue);
      });

      test('catches forbidden vocabulary', () {
        expect(NotificationPolicy.leaksSensitiveContent('Kasat update'), isTrue);
        expect(
          NotificationPolicy.leaksSensitiveContent('Your case was updated'),
          isTrue,
        );
        expect(
          NotificationPolicy.leaksSensitiveContent('The police responded'),
          isTrue,
        );
      });

      test('passes the approved copy', () {
        expect(
          NotificationPolicy.leaksSensitiveContent('You have an update.'),
          isFalse,
        );
        expect(
          NotificationPolicy.leaksSensitiveContent('You have an update'),
          isFalse,
        );
      });
    });
  });
}
