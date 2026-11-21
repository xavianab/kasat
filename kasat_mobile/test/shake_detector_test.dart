import 'package:flutter_test/flutter_test.dart';
import 'package:kasat_mobile/features/duress/shake_detector.dart';

void main() {
  late ShakeDetector detector;
  final g = 9.80665;
  // Above the 1.8 g default threshold.
  double above() => 2.0 * g;
  double below() => 0.4 * g;

  setUp(() {
    detector = ShakeDetector();
  });

  void peakAt(DateTime t) {
    expect(detector.considerMagnitude(t, above()), isFalse);
    detector.considerMagnitude(t.add(const Duration(milliseconds: 20)), below());
  }

  test('default threshold is about 1.8 g', () {
    expect(detector.peakThresholdG, closeTo(1.8, 0.01));
  });

  test('3 shakes in 2 seconds triggers', () {
    final t0 = DateTime.utc(2026, 1, 1, 12);
    peakAt(t0);
    peakAt(t0.add(const Duration(milliseconds: 400)));
    final fired = detector.considerMagnitude(
      t0.add(const Duration(milliseconds: 800)),
      above(),
    );
    expect(fired, isTrue);
  });

  test('2 shakes does not trigger', () {
    final t0 = DateTime.utc(2026, 1, 1, 12);
    peakAt(t0);
    final second = detector.considerMagnitude(
      t0.add(const Duration(milliseconds: 400)),
      above(),
    );
    expect(second, isFalse);
    // Still only 2 peaks even after reset below threshold.
    detector.considerMagnitude(
      t0.add(const Duration(milliseconds: 420)),
      below(),
    );
    expect(
      detector.considerMagnitude(
        t0.add(const Duration(seconds: 3)),
        above(),
      ),
      isFalse,
    );
  });

  test('walking pattern does not trigger', () {
    final t0 = DateTime.utc(2026, 1, 1, 12);
    // Typical walking user-accel stays well under 1.8 g.
    for (var i = 0; i < 40; i++) {
      final mag = (0.3 + (i.isEven ? 0.4 : 0.1)) * g;
      expect(
        detector.considerMagnitude(
          t0.add(Duration(milliseconds: i * 50)),
          mag,
        ),
        isFalse,
      );
    }
  });

  test('running pattern does not trigger', () {
    final t0 = DateTime.utc(2026, 1, 1, 12);
    // Normal running peaks around 1.2 to 1.5 g, under the 1.8 g bar.
    for (var i = 0; i < 30; i++) {
      final high = i.isEven;
      final mag = (high ? 1.5 : 0.4) * g;
      expect(
        detector.considerMagnitude(
          t0.add(Duration(milliseconds: i * 80)),
          mag,
        ),
        isFalse,
      );
    }
  });

  test('at 1.8 g threshold, normal walking and running still do not trigger', () {
    final tuned = ShakeDetector(peakThresholdG: 1.8);
    final t0 = DateTime.utc(2026, 1, 1, 12);

    for (var i = 0; i < 50; i++) {
      // Walk / jog mix: alternate soft and firm steps under 1.8 g.
      final mag = (i % 3 == 0 ? 1.4 : (i.isEven ? 0.9 : 0.35)) * g;
      expect(
        tuned.considerMagnitude(
          t0.add(Duration(milliseconds: i * 60)),
          mag,
        ),
        isFalse,
        reason: 'sample $i at ${(mag / g).toStringAsFixed(2)} g should not fire',
      );
    }
  });

  test('cooldown blocks a second trigger for 30 seconds', () {
    final t0 = DateTime.utc(2026, 1, 1, 12);
    peakAt(t0);
    peakAt(t0.add(const Duration(milliseconds: 300)));
    expect(
      detector.considerMagnitude(
        t0.add(const Duration(milliseconds: 600)),
        above(),
      ),
      isTrue,
    );

    // Immediate retry inside the window must not fire.
    detector.considerMagnitude(
      t0.add(const Duration(milliseconds: 650)),
      below(),
    );
    peakAt(t0.add(const Duration(seconds: 1)));
    peakAt(t0.add(const Duration(seconds: 1, milliseconds: 300)));
    expect(
      detector.considerMagnitude(
        t0.add(const Duration(seconds: 1, milliseconds: 600)),
        above(),
      ),
      isFalse,
    );
    // Clear hysteresis left by the blocked peak before the next window.
    detector.considerMagnitude(
      t0.add(const Duration(seconds: 1, milliseconds: 620)),
      below(),
    );

    // After cooldown, three peaks fire again.
    final t1 = t0.add(const Duration(seconds: 31));
    peakAt(t1);
    peakAt(t1.add(const Duration(milliseconds: 300)));
    expect(
      detector.considerMagnitude(
        t1.add(const Duration(milliseconds: 600)),
        above(),
      ),
      isTrue,
    );
  });
}
