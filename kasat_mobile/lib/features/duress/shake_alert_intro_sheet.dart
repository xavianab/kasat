import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app.dart';
import '../../theme/kasat_theme.dart';
import '../../widgets/kasat_button.dart';
import 'shake_detector.dart';
import 'shake_listener.dart';

/// First-time explanation when she turns on "Shake phone to alert".
/// Includes a practice mode that shows "Shake detected" and sends nothing.
class ShakeAlertIntroSheet extends StatefulWidget {
  const ShakeAlertIntroSheet({super.key});

  static const sheetKey = Key('shake-alert-intro-sheet');
  static const tryItKey = Key('shake-alert-try-it');
  static const turnOnKey = Key('shake-alert-turn-on');
  static const cancelKey = Key('shake-alert-intro-cancel');
  static const detectedKey = Key('shake-alert-detected');
  static const peakMeterKey = Key('shake-alert-peak-meter');

  /// Live g meter is for debug / profile / test builds only, never release.
  static bool get showPeakMeter => !kReleaseMode;

  static Future<bool> show(BuildContext context) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: KC.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => const ShakeAlertIntroSheet(),
    );
    return result == true;
  }

  @override
  State<ShakeAlertIntroSheet> createState() => _ShakeAlertIntroSheetState();
}

class _ShakeAlertIntroSheetState extends State<ShakeAlertIntroSheet> {
  bool _practicing = false;
  bool _detected = false;
  final _practiceDetector = ShakeDetector()..resetAll();
  double _liveG = 0;
  double _peakG = 0;
  DateTime? _lastMeterUi;

  void _onMagnitude(double magMs2) {
    if (!ShakeAlertIntroSheet.showPeakMeter) return;
    final g = magMs2 / _practiceDetector.gravityMs2;
    final now = DateTime.now();
    final peak = g > _peakG ? g : _peakG;
    // Throttle UI so the sheet stays readable while sampling at game rate.
    if (_lastMeterUi != null &&
        now.difference(_lastMeterUi!) < const Duration(milliseconds: 80) &&
        peak == _peakG) {
      return;
    }
    _lastMeterUi = now;
    if (!mounted) return;
    setState(() {
      _liveG = g;
      _peakG = peak;
    });
  }

  @override
  Widget build(BuildContext context) {
    final i18n = KasatScope.of(context).i18n;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final threshold = _practiceDetector.peakThresholdG;

    Widget body = Padding(
      key: ShakeAlertIntroSheet.sheetKey,
      padding: EdgeInsets.fromLTRB(
        KSpace.lg,
        KSpace.md,
        KSpace.lg,
        KSpace.lg + bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: KSpace.md),
                decoration: BoxDecoration(
                  color: KC.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              i18n.t('settings.shakeIntroTitle'),
              style: KType.sans(size: 18, weight: FontWeight.w600),
            ),
            const SizedBox(height: KSpace.sm),
            Text(
              i18n.t('settings.shakeIntroBody'),
              style: KType.sans(size: 14, color: KC.muted, height: 1.45),
            ),
            const SizedBox(height: KSpace.md),
            if (_practicing) ...[
              Text(
                _detected
                    ? i18n.t('settings.shakeDetected')
                    : i18n.t('settings.shakeTryHint'),
                key: _detected ? ShakeAlertIntroSheet.detectedKey : null,
                textAlign: TextAlign.center,
                style: KType.sans(
                  size: 15,
                  weight: FontWeight.w600,
                  color: _detected ? KC.urgent : KC.text,
                ),
              ),
              if (ShakeAlertIntroSheet.showPeakMeter) ...[
                const SizedBox(height: KSpace.sm),
                Text(
                  'Live ${_liveG.toStringAsFixed(2)} g   '
                  'Peak ${_peakG.toStringAsFixed(2)} g   '
                  'Need ${threshold.toStringAsFixed(1)} g x3',
                  key: ShakeAlertIntroSheet.peakMeterKey,
                  textAlign: TextAlign.center,
                  style: KType.sans(size: 13, color: KC.muted, height: 1.35),
                ),
              ],
              const SizedBox(height: KSpace.md),
            ],
            KButton(
              key: ShakeAlertIntroSheet.tryItKey,
              label: i18n.t('settings.shakeTryIt'),
              kind: KButtonKind.secondary,
              icon: Icons.vibration_rounded,
              compact: true,
              onPressed: () {
                setState(() {
                  _practicing = true;
                  _detected = false;
                  _liveG = 0;
                  _peakG = 0;
                });
                _practiceDetector.resetAll();
              },
            ),
            const SizedBox(height: KSpace.sm),
            KButton(
              key: ShakeAlertIntroSheet.turnOnKey,
              label: i18n.t('settings.shakeIntroDone'),
              kind: KButtonKind.primary,
              compact: true,
              onPressed: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: KSpace.sm),
            TextButton(
              key: ShakeAlertIntroSheet.cancelKey,
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                i18n.t('settings.shakeIntroCancel'),
                style: KType.sans(size: 14, color: KC.muted),
              ),
            ),
          ],
        ),
      ),
    );

    if (_practicing) {
      body = ShakeListener(
        enabled: true,
        detector: _practiceDetector,
        onMagnitude: _onMagnitude,
        onShake: () {
          HapticFeedback.mediumImpact();
          if (!mounted) return;
          setState(() => _detected = true);
        },
        child: body,
      );
    }

    return SafeArea(child: body);
  }
}
