import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app.dart';
import '../../core/kasat_config.dart';
import '../../theme/kasat_theme.dart';

/// 5-second automatic-escalation countdown modeled on vehicle crash detection
/// and retail panic buttons.
///
/// - Starts immediately on tap with heavy haptic feedback.
/// - Large high-contrast CANCEL button cancels immediately with zero side effects.
/// - Includes a "Silent / discreet mode" toggle for when the abuser is present
///   (dims the screen, stops vibration, skips opening the phone dialer, and
///   silently dispatches the URGENT alert + 30-min live GPS to police).
class DangerCountdownSheet extends StatefulWidget {
  const DangerCountdownSheet({super.key});

  static const cancelButtonKey = Key('danger-cancel-button');
  static const silentToggleKey = Key('danger-silent-toggle');

  static Future<void> show(BuildContext context) {
    HapticFeedback.heavyImpact();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => const DangerCountdownSheet(),
    );
  }

  @override
  State<DangerCountdownSheet> createState() => _DangerCountdownSheetState();
}

class _DangerCountdownSheetState extends State<DangerCountdownSheet> {
  late int _secondsRemaining = KasatConfig.dangerCountdown.inSeconds;
  bool _silent = false;
  bool _firing = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsRemaining <= 1) {
        timer.cancel();
        _triggerEscalation();
      } else {
        setState(() => _secondsRemaining--);
        if (!_silent) {
          HapticFeedback.mediumImpact();
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _cancel() {
    _timer?.cancel();
    if (!_silent) {
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
    if (!_silent) {
      HapticFeedback.heavyImpact();
    }
    final scope = KasatScope.of(context);
    await scope.danger.escalateNow(silent: _silent);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _silent ? const Color(0xFF0E0D0D) : const Color(0xFF281113);
    final textColor = _silent ? const Color(0xFF8C8583) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(KRadius.xl)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            KSpace.xl,
            KSpace.xl,
            KSpace.xl,
            KSpace.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: KSpace.md,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _silent
                          ? Colors.white.withValues(alpha: 0.08)
                          : KC.urgent,
                      borderRadius: KRadius.rPill,
                    ),
                    child: Text(
                      _silent ? 'SILENT ALERT' : 'EMERGENCY ESCALATION',
                      style: KType.sans(
                        size: 11.5,
                        weight: FontWeight.w700,
                        color: textColor,
                      ).copyWith(letterSpacing: 0.6),
                    ),
                  ),
                  const SizedBox(width: KSpace.sm),
                  Flexible(
                    child: Text(
                      'Line: ${KasatConfig.emergencyNumber} (placeholder)',
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: KType.code(
                        size: 11.5,
                        color: textColor.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: KSpace.xl),
              Center(
                child: Container(
                  width: 116,
                  height: 116,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _silent
                        ? Colors.white.withValues(alpha: 0.05)
                        : KC.urgent.withValues(alpha: 0.22),
                    border: Border.all(
                      color: _silent
                          ? Colors.white.withValues(alpha: 0.2)
                          : KC.urgent,
                      width: 3,
                    ),
                  ),
                  child: Text(
                    _firing ? '…' : '$_secondsRemaining',
                    style: KType.serif(
                      size: 54,
                      weight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: KSpace.lg),
              Text(
                _firing
                    ? 'Sending urgent alert & live location…'
                    : _silent
                        ? 'Silent alert in $_secondsRemaining s — screen dimmed, no phone call'
                        : 'Alerting police & opening dialer in $_secondsRemaining s',
                textAlign: TextAlign.center,
                style: KType.serif(
                  size: 22,
                  weight: FontWeight.w600,
                  color: textColor,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: KSpace.sm),
              Text(
                _silent
                    ? 'Your live GPS location will stream silently to the police portal for ${KasatConfig.dangerLiveLocationMinutes} minutes. The phone dialer will not open.'
                    : 'At 0, Kasat pins an URGENT alert with your live GPS to the police queue and opens the dialer pre-filled with ${KasatConfig.emergencyNumber} so you tap once to connect.',
                textAlign: TextAlign.center,
                style: KType.sans(
                  size: 13.5,
                  color: textColor.withValues(alpha: 0.78),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: KSpace.lg),
              GestureDetector(
                key: DangerCountdownSheet.silentToggleKey,
                onTap: () => setState(() => _silent = !_silent),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: KSpace.md,
                    vertical: KSpace.md,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: _silent ? 0.06 : 0.1),
                    borderRadius: KRadius.rMd,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _silent
                            ? Icons.visibility_off_rounded
                            : Icons.volume_off_outlined,
                        color: textColor,
                        size: 20,
                      ),
                      const SizedBox(width: KSpace.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Abuser is nearby — silent mode',
                              style: KType.sans(
                                size: 14,
                                weight: FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                            Text(
                              'Dims screen, stops vibration, and skips phone call while still sending live GPS to police.',
                              style: KType.sans(
                                size: 12,
                                color: textColor.withValues(alpha: 0.72),
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: _silent,
                        activeThumbColor: KC.calm,
                        onChanged: (v) => setState(() => _silent = v),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: KSpace.xl),
              SizedBox(
                height: 62,
                child: ElevatedButton.icon(
                  key: DangerCountdownSheet.cancelButtonKey,
                  onPressed: _firing ? null : _cancel,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF1F1617),
                    shape: const RoundedRectangleBorder(
                      borderRadius: KRadius.rPill,
                    ),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.close_rounded, size: 24),
                  label: Text(
                    'CANCEL — I AM SAFE',
                    style: KType.sans(
                      size: 16,
                      weight: FontWeight.w700,
                      color: const Color(0xFF1F1617),
                    ).copyWith(letterSpacing: 0.4),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
