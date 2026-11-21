import 'package:flutter_test/flutter_test.dart';
import 'package:kasat_mobile/features/duress/shake_detector.dart';

void main() {
  late ShakeDetector detector;
  final g = 9.80665;
  double above() => 2.8 * g;
  double below() => 0.5 * g;

  setUp(() {
    detector = ShakeDetector();
  });

  void peakAt(DateTime t) {
    expect(detector.considerMagnitude(t, above()), isFalse);
    detector.considerMagnitude(t.add(const Duration(milliseconds: 20)), below());
  }

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
    // Typical walking user-accel stays well under 2.7 g.
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
    // Hard running can approach ~2 g but not three 2.7 g peaks.
    for (var i = 0; i < 30; i++) {
      final high = i.isEven;
      final mag = (high ? 2.0 : 0.4) * g;
      expect(
        detector.considerMagnitude(
          t0.add(Duration(milliseconds: i * 80)),
          mag,
        ),
        isFalse,
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
