/// Pure shake peak logic shared by [ShakeListener] and unit tests.
///
/// Expects samples that are already net of gravity (for example from
/// `userAccelerometerEventStream`), in m/s².
class ShakeDetector {
  ShakeDetector({
    this.peakThresholdG = 1.8,
    this.resetThresholdG = 0.7,
    this.window = const Duration(seconds: 2),
    this.peaksRequired = 3,
    this.cooldown = const Duration(seconds: 30),
    this.gravityMs2 = 9.80665,
  });

  /// Peak must exceed this many g (net of gravity) to count.
  final double peakThresholdG;
  final double resetThresholdG;
  final Duration window;
  final int peaksRequired;
  final Duration cooldown;
  final double gravityMs2;

  double get peakThresholdMs2 => peakThresholdG * gravityMs2;
  double get resetThresholdMs2 => resetThresholdG * gravityMs2;

  DateTime? _windowStart;
  DateTime? _lastFire;
  int _peaks = 0;
  bool _inPeak = false;

  /// Feeds one magnitude sample. Returns true when a shake trigger fires.
  bool considerMagnitude(DateTime now, double magnitudeMs2) {
    // Always update hysteresis so a peak that ends during cooldown can
    // clear before the next real attempt.
    if (magnitudeMs2 <= resetThresholdMs2) {
      _inPeak = false;
    }

    final coolingDown =
        _lastFire != null && now.difference(_lastFire!) < cooldown;

    if (magnitudeMs2 >= peakThresholdMs2) {
      if (_inPeak) return false;
      _inPeak = true;
      if (coolingDown) return false;

      if (_windowStart == null || now.difference(_windowStart!) > window) {
        _windowStart = now;
        _peaks = 1;
        return false;
      }

      _peaks++;
      if (_peaks < peaksRequired) return false;

      _lastFire = now;
      _peaks = 0;
      _windowStart = null;
      return true;
    }

    return false;
  }

  void reset() {
    _windowStart = null;
    _peaks = 0;
    _inPeak = false;
  }

  /// Clears cooldown as well (tests / practice restart).
  void resetAll() {
    reset();
    _lastFire = null;
  }
}
