import 'package:flutter_test/flutter_test.dart';
import 'package:kasat_mobile/core/crisis_detection.dart';
import 'package:kasat_mobile/models/incident_category.dart';

void main() {
  CrisisSignal evaluate(String description, [IncidentCategory? category]) {
    return CrisisDetection.evaluate(category: category, description: description);
  }

  group('CrisisDetection', () {
    test('triggers on the emergency category regardless of wording', () {
      final signal = evaluate('', IncidentCategory.criticalEmergency);

      expect(signal.triggered, isTrue);
      expect(signal.reason, isNotNull);
    });

    test('triggers on wording that suggests danger is present', () {
      expect(evaluate('he is still outside my building').triggered, isTrue);
      expect(evaluate('I think he is following me home').triggered, isTrue);
      expect(evaluate('She is bleeding and will not wake up').triggered, isTrue);
      expect(evaluate('He said he is going to kill me tonight').triggered, isTrue);
    });

    test('is case insensitive', () {
      expect(evaluate('HE IS STILL OUTSIDE').triggered, isTrue);
    });

    test('stays quiet for a report of something already over', () {
      expect(
        evaluate(
          'Last month a supervisor took my wages and threatened to report me '
          'to immigration if I complained about it.',
        ).triggered,
        isFalse,
      );
      expect(evaluate('').triggered, isFalse);
    });

    test('does not fire on merely distressed language', () {
      // A banner that appears on every report is a banner nobody reads, so
      // broad emotional words must not match.
      for (final text in [
        'I was scared and I am still upset about it',
        'he hurt me badly last year',
        'I feel unsafe walking there',
      ]) {
        expect(evaluate(text).triggered, isFalse, reason: text);
      }
    });

    test('explains itself, so the banner is never unexplained', () {
      expect(evaluate('he is still outside').reason, isNotEmpty);
      expect(evaluate('', IncidentCategory.criticalEmergency).reason, isNotEmpty);
    });

    test('a non-emergency category alone does not trigger', () {
      expect(
        evaluate('Someone took money from my account', IncidentCategory.fraud)
            .triggered,
        isFalse,
      );
    });
  });
}
