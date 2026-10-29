import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Foreground-only shake. Locked-screen / background detection is Phase 2.
class ShakeListener extends StatefulWidget {
  const ShakeListener({
    super.key,
    required this.enabled,
    required this.onShake,
    required this.child,
  });

  final bool enabled;
  final VoidCallback onShake;
  final Widget child;

  @override
  State<ShakeListener> createState() => _ShakeListenerState();
}

class _ShakeListenerState extends State<ShakeListener> {
  StreamSubscription<AccelerometerEvent>? _sub;
  DateTime? _lastFire;
  int _peaks = 0;
  DateTime? _windowStart;

  @override
  void initState() {
    super.initState();
    if (widget.enabled) _listen();
  }

  @override
  void didUpdateWidget(ShakeListener oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && _sub == null) {
      _listen();
    } else if (!widget.enabled) {
      _sub?.cancel();
      _sub = null;
    }
  }

  void _listen() {
    try {
      _sub = accelerometerEventStream().listen(
        (event) {
          final g = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
          if (g < 22) return;
          final now = DateTime.now();
          if (_windowStart == null ||
              now.difference(_windowStart!) > const Duration(milliseconds: 800)) {
            _windowStart = now;
            _peaks = 1;
            return;
          }
          _peaks++;
          if (_peaks < 3) return;
          if (_lastFire != null && now.difference(_lastFire!) < const Duration(seconds: 4)) {
            return;
          }
          _lastFire = now;
          _peaks = 0;
          widget.onShake();
        },
        onError: (_) {},
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
