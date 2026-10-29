import 'package:flutter_test/flutter_test.dart';
import 'package:kasat_mobile/core/tracking_id.dart';

void main() {
  group('TrackingId.generate', () {
    test('produces KST-XXXXX in the safe alphabet', () {
      for (var i = 0; i < 500; i++) {
        final id = TrackingId.generate();
        expect(id, matches(RegExp(r'^KST-[A-Z2-9]{5}$')));
        expect(TrackingId.isValid(id), isTrue);
      }
    });

    test('never emits characters that are ambiguous when read aloud', () {
      const banned = ['0', 'O', '1', 'I', 'L', 'U'];
      for (var i = 0; i < 500; i++) {
        final body = TrackingId.generate().substring(4);
        for (final c in banned) {
          expect(body.contains(c), isFalse, reason: 'leaked "$c" in $body');
        }
      }
    });

    test('collides rarely enough to be usable', () {
      final seen = <String>{};
      for (var i = 0; i < 2000; i++) {
        seen.add(TrackingId.generate());
      }
      expect(seen.length, greaterThan(1990));
    });
  });

  group('TrackingId.normalize', () {
    test('accepts the forms a human actually types', () {
      const expected = 'KST-8X9P2';
      for (final input in [
        'KST-8X9P2',
        'kst-8x9p2',
        'KST8X9P2',
        '8X9P2',
        '  kst 8x9p2  ',
      ]) {
        expect(TrackingId.normalize(input), expected, reason: 'failed on "$input"');
      }
    });

    test('rejects wrong lengths and out-of-alphabet characters', () {
      for (final input in ['', 'KST-', 'KST-8X9P', 'KST-8X9P2Q', 'KST-8X9P0', 'KST-IIIII']) {
        expect(TrackingId.normalize(input), isNull, reason: 'accepted "$input"');
      }
    });
  });
}
