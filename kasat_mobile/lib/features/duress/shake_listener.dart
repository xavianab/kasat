import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'shake_detector.dart';

/// Foreground-only shake. Locked-screen / background detection is Phase 2.
///
/// One detector for the whole app. Used for gated shake-to-SMS and for the
/// opt-in "Shake phone to alert" emergency countdown.
class ShakeListener extends StatefulWidget {
  const ShakeListener({
    super.key,
    required this.enabled,
    required this.onShake,
    required this.child,
    this.detector,
    this.userAccelerometerStream,
    this.accelerometerStream,
  });

  final bool enabled;
  final VoidCallback onShake;
  final Widget child;

  /// Optional shared detector (tests). A fresh one is created otherwise.
  final ShakeDetector? detector;

  /// Injectable streams for tests. Production uses sensors_plus.
  final Stream<UserAccelerometerEvent>? userAccelerometerStream;
  final Stream<AccelerometerEvent>? accelerometerStream;

  @override
  State<ShakeListener> createState() => _ShakeListenerState();
}

class _ShakeListenerState extends State<ShakeListener>
    with WidgetsBindingObserver {
  StreamSubscription<dynamic>? _sub;
  late final ShakeDetector _detector =
      widget.detector ?? ShakeDetector();
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
    if (widget.enabled && _foreground) _listen();
  }

  @override
  void didUpdateWidget(ShakeListener oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncSubscription();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncSubscription();
  }

  void _syncSubscription() {
    final shouldListen = widget.enabled && _foreground;
    if (shouldListen && _sub == null) {
      _listen();
    } else if (!shouldListen) {
      _sub?.cancel();
      _sub = null;
      _detector.reset();
    }
  }

  void _listen() {
    _sub?.cancel();
    try {
      final userStream =
          widget.userAccelerometerStream ?? userAccelerometerEventStream();
      _sub = userStream.listen(
        (event) {
          final mag = sqrt(
            event.x * event.x + event.y * event.y + event.z * event.z,
          );
          if (_detector.considerMagnitude(DateTime.now(), mag)) {
            widget.onShake();
          }
        },
        onError: (_) {
          // Fall back to raw accelerometer with gravity subtracted.
          _listenAccelerometerFallback();
        },
      );
    } catch (_) {
      _listenAccelerometerFallback();
    }
  }

  void _listenAccelerometerFallback() {
    _sub?.cancel();
    try {
      final stream = widget.accelerometerStream ?? accelerometerEventStream();
      _sub = stream.listen(
        (event) {
          final raw = sqrt(
            event.x * event.x + event.y * event.y + event.z * event.z,
          );
          final mag = (raw - _detector.gravityMs2).abs();
          if (_detector.considerMagnitude(DateTime.now(), mag)) {
            widget.onShake();
          }
        },
        onError: (_) {},
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
