import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app.dart';
import '../../core/kasat_config.dart';
import '../../models/incident_status.dart';
import '../../theme/kasat_theme.dart';

/// Full-screen automatic-escalation countdown modeled on vehicle crash
/// detection and retail panic buttons.
///
/// Behaviour is unchanged from the previous sheet:
/// - Starts immediately on tap with heavy haptic feedback.
/// - Large CANCEL button cancels immediately with zero side effects.
/// - Silent mode dims the screen, stops vibration, skips the dialer, and still
///   dispatches the urgent alert + live GPS to police.
class DangerCountdownSheet extends StatefulWidget {
  const DangerCountdownSheet({
    super.key,
    this.initialSilent = false,
    this.startedByShake = false,
  });

  /// Opens already in silent mode (used by shake-to-alert).
  final bool initialSilent;

  /// Desk-facing flag: mark the resulting alert "Started by shake".
  final bool startedByShake;

  static const cancelButtonKey = Key('danger-cancel-button');
  static const silentToggleKey = Key('danger-silent-toggle');
  static const queuedDoneKey = Key('danger-queued-done');
  static const queuedCallKey = Key('danger-queued-call');
  static const queuedMessageKey = Key('danger-queued-message');
  static const ringKey = Key('danger-countdown-ring');

  static bool _visible = false;

  /// Clears the in-flight guard (widget tests that tear down mid-route).
  @visibleForTesting
  static void debugResetVisible() => _visible = false;

  static Future<void> show(
    BuildContext context, {
    bool initialSilent = false,
    bool startedByShake = false,
  }) {
    if (_visible) return Future<void>.value();
    _visible = true;
    HapticFeedback.heavyImpact();
    return Navigator.of(context, rootNavigator: true)
        .push<void>(
      PageRouteBuilder<void>(
        opaque: true,
        barrierDismissible: false,
        transitionDuration: const Duration(milliseconds: 180),
        reverseTransitionDuration: const Duration(milliseconds: 140),
        pageBuilder: (context, animation, secondaryAnimation) {
          return DangerCountdownSheet(
            initialSilent: initialSilent,
            startedByShake: startedByShake,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    )
        .whenComplete(() => _visible = false);
  }

  @override
  State<DangerCountdownSheet> createState() => _DangerCountdownSheetState();
}

class _DangerCountdownSheetState extends State<DangerCountdownSheet>
    with SingleTickerProviderStateMixin {
  late int _secondsRemaining = KasatConfig.dangerCountdown.inSeconds;
  late bool _silent = widget.initialSilent;
  bool _firing = false;
  bool _showQueuedFallback = false;
  Timer? _timer;
  late final AnimationController _ring;
  bool _reduceMotion = false;
  bool _started = false;

  int get _totalSeconds => KasatConfig.dangerCountdown.inSeconds;

  /// Shake-started silent mode still vibrates (vibration only, no dialer).
  bool get _shouldVibrate => !_silent || widget.startedByShake;

  @override
  void initState() {
    super.initState();
    _ring = AnimationController(
      vsync: this,
      duration: KasatConfig.dangerCountdown,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion) {
      _ring.value = 0;
    } else {
      _ring.forward();
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsRemaining <= 1) {
        timer.cancel();
        _triggerEscalation();
      } else {
        setState(() => _secondsRemaining--);
        if (_reduceMotion) {
          final done = _totalSeconds - _secondsRemaining;
          _ring.value = done / _totalSeconds;
        }
        if (_shouldVibrate) {
          HapticFeedback.mediumImpact();
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ring.dispose();
    super.dispose();
  }

  void _cancel() {
    _timer?.cancel();
    if (_shouldVibrate) {
      HapticFeedback.lightImpact();
    }
    Navigator.of(context).pop();
  }

  Future<void> _triggerEscalation() async {
    if (_firing) return;
    setState(() {
      _firing = true;
      _secondsRemaining = 0;
    });
    _ring.value = 1;
    if (_shouldVibrate) {
      HapticFeedback.heavyImpact();
    }
    final scope = KasatScope.of(context);
    final incident = await scope.danger.escalateNow(
      silent: _silent,
      startedByShake: widget.startedByShake,
    );
    if (!mounted) return;
    if (incident.status == IncidentStatus.queued) {
      setState(() => _showQueuedFallback = true);
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final i18n = KasatScope.of(context).i18n;
    final canvas = KC.canvas;
    final bg = _silent
        ? Color.lerp(canvas, const Color(0xFF000000), 0.55)!
        : canvas;
    final textColor = _silent ? KC.muted : KC.text;

    if (_showQueuedFallback) {
      return Container(
        color: bg,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              KSpace.xl,
              KSpace.xl,
              KSpace.xl,
              KSpace.xl,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  i18n.t('danger.queuedTitle'),
                  textAlign: TextAlign.center,
                  style: KType.serif(
                    size: 22,
                    weight: FontWeight.w600,
                    color: textColor,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: KSpace.md),
                Text(
                  key: DangerCountdownSheet.queuedMessageKey,
                  _silent
                      ? i18n.t(
                          'danger.queuedBodySilent',
                          {'number': KasatConfig.emergencyNumber},
                        )
                      : i18n.t(
                          'danger.queuedBody',
                          {'number': KasatConfig.emergencyNumber},
                        ),
                  textAlign: TextAlign.center,
                  style: KType.sans(
                    size: 14.5,
                    color: textColor.withValues(alpha: 0.85),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: KSpace.xl),
                if (_silent) ...[
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      key: DangerCountdownSheet.queuedCallKey,
                      onPressed: () {
                        unawaited(
                          KasatScope.of(context).danger.openEmergencyDialer(),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: KC.text,
                        foregroundColor: KC.canvas,
                        shape: const RoundedRectangleBorder(
                          borderRadius: KRadius.rPill,
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        i18n.t(
                          'danger.queuedCall',
                          {'number': KasatConfig.emergencyNumber},
                        ),
                        style: KType.sans(
                          size: 15,
                          weight: FontWeight.w700,
                          color: KC.canvas,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: KSpace.md),
                ],
                SizedBox(
                  height: 56,
                  child: OutlinedButton(
                    key: DangerCountdownSheet.queuedDoneKey,
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textColor,
                      side: BorderSide(color: textColor.withValues(alpha: 0.35)),
                      shape: const RoundedRectangleBorder(
                        borderRadius: KRadius.rPill,
                      ),
                    ),
                    child: Text(
                      i18n.t('danger.queuedDone'),
                      style: KType.sans(
                        size: 15,
                        weight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final title = _firing
        ? i18n.t('danger.sending')
        : _silent
            ? i18n.t('danger.silentCountdown', {'secs': '$_secondsRemaining'})
            : i18n.t('danger.countdown', {'secs': '$_secondsRemaining'});
    final body = _silent
        ? i18n.t('danger.bodySilent', {
            'number': KasatConfig.emergencyNumber,
          })
        : i18n.t('danger.body', {
            'number': KasatConfig.emergencyNumber,
          });
    final semantics = i18n.t('danger.semantics', {
      'secs': '$_secondsRemaining',
    });

    return ListenableBuilder(
      listenable: i18n,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: bg,
          body: SafeArea(
            child: Semantics(
              container: true,
              liveRegion: true,
              label: semantics,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  KSpace.lg,
                  KSpace.md,
                  KSpace.lg,
                  KSpace.lg,
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: ClipRect(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return SingleChildScrollView(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: constraints.maxHeight,
                                ),
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 420,
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        i18n.t('danger.label'),
                                        textAlign: TextAlign.center,
                                        style: KType.sans(
                                          size: 13,
                                          weight: FontWeight.w600,
                                          color: KC.urgent,
                                        ),
                                      ),
                                      const SizedBox(height: KSpace.xl),
                                      _CountdownRing(
                                        key: DangerCountdownSheet.ringKey,
                                        progress: _ring,
                                        reduceMotion: _reduceMotion,
                                        firing: _firing,
                                        seconds: _secondsRemaining,
                                        trackColor: KC.border,
                                        progressColor: KC.urgent,
                                        numberColor: KC.text,
                                      ),
                                      const SizedBox(height: KSpace.xl),
                                      Text(
                                        title,
                                        textAlign: TextAlign.center,
                                        style: KType.sans(
                                          size: 20,
                                          weight: FontWeight.w600,
                                          color: KC.text,
                                          height: 1.25,
                                        ),
                                      ),
                                      const SizedBox(height: KSpace.sm),
                                      Text(
                                        body,
                                        textAlign: TextAlign.center,
                                        style: KType.sans(
                                          size: 14,
                                          color: KC.muted,
                                          height: 1.4,
                                        ),
                                      ),
                                      const SizedBox(height: KSpace.xl),
                                      _SilentModeCard(
                                        silent: _silent,
                                        title: i18n.t('danger.silentModeTitle'),
                                        detail: i18n.t('danger.silentModeBody'),
                                        onChanged: (v) =>
                                            setState(() => _silent = v),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: KSpace.md),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: OutlinedButton(
                        key: DangerCountdownSheet.cancelButtonKey,
                        onPressed: _firing ? null : _cancel,
                        style: OutlinedButton.styleFrom(
                          backgroundColor: KC.surface,
                          foregroundColor: KC.text,
                          disabledForegroundColor: KC.muted,
                          side: BorderSide(color: KC.border),
                          shape: const RoundedRectangleBorder(
                            borderRadius: KRadius.rMd,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: KSpace.md,
                          ),
                        ),
                        child: Text(
                          i18n.t('danger.cancel'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: KType.sans(
                            size: 16,
                            weight: FontWeight.w600,
                            color: KC.text,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SilentModeCard extends StatelessWidget {
  const _SilentModeCard({
    required this.silent,
    required this.title,
    required this.detail,
    required this.onChanged,
  });

  final bool silent;
  final String title;
  final String detail;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: KC.surface,
      shape: RoundedRectangleBorder(
        borderRadius: KRadius.rMd,
        side: BorderSide(color: KC.border),
      ),
      child: InkWell(
        key: DangerCountdownSheet.silentToggleKey,
        onTap: () => onChanged(!silent),
        borderRadius: KRadius.rMd,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            KSpace.md,
            KSpace.md,
            KSpace.sm,
            KSpace.md,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: KType.sans(
                        size: 14,
                        weight: FontWeight.w600,
                        color: KC.text,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      detail,
                      style: KType.sans(
                        size: 12.5,
                        color: KC.muted,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: KSpace.sm),
              Switch.adaptive(
                value: silent,
                activeThumbColor: KC.calm,
                onChanged: onChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountdownRing extends StatelessWidget {
  const _CountdownRing({
    super.key,
    required this.progress,
    required this.reduceMotion,
    required this.firing,
    required this.seconds,
    required this.trackColor,
    required this.progressColor,
    required this.numberColor,
  });

  final Animation<double> progress;
  final bool reduceMotion;
  final bool firing;
  final int seconds;
  final Color trackColor;
  final Color progressColor;
  final Color numberColor;

  static const _size = 220.0;
  static const _stroke = 12.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _size,
      height: _size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: progress,
              builder: (context, _) {
                return CustomPaint(
                  size: const Size.square(_size),
                  painter: _CountdownRingPainter(
                    progress: firing ? 1 : progress.value,
                    trackColor: trackColor,
                    progressColor: progressColor,
                    strokeWidth: _stroke,
                    filled: firing,
                  ),
                );
              },
            ),
          ),
          if (firing)
            const Icon(
              Icons.phone_rounded,
              size: 64,
              color: Colors.white,
            )
          else
            AnimatedSwitcher(
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 150),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.88, end: 1).animate(
                      animation,
                    ),
                    child: child,
                  ),
                );
              },
              child: Text(
                '$seconds',
                key: ValueKey<int>(seconds),
                style: KType.sans(
                  size: 88,
                  weight: FontWeight.w700,
                  color: numberColor,
                  height: 1,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CountdownRingPainter extends CustomPainter {
  _CountdownRingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    required this.strokeWidth,
    required this.filled,
  });

  final double progress;
  final Color trackColor;
  final Color progressColor;
  final double strokeWidth;
  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    if (filled) {
      canvas.drawCircle(
        center,
        radius + strokeWidth / 2,
        Paint()
          ..color = progressColor
          ..style = PaintingStyle.fill
          ..isAntiAlias = true,
      );
      return;
    }

    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    canvas.drawCircle(center, radius, track);

    final sweep = (progress.clamp(0.0, 1.0)) * math.pi * 2;
    if (sweep <= 0) return;

    final arc = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    canvas.drawArc(rect, -math.pi / 2, sweep, false, arc);
  }

  @override
  bool shouldRepaint(covariant _CountdownRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.filled != filled;
  }
}
