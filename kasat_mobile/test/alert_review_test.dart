import 'package:flutter_test/flutter_test.dart';
import 'package:kasat_mobile/core/alert_id.dart';
import 'package:kasat_mobile/core/alert_review.dart';
import 'package:kasat_mobile/core/tracking_id.dart';

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
}
