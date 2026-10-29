import 'dart:async';

import 'package:flutter/material.dart';

import '../../../models/incident.dart';
import '../../../theme/kasat_theme.dart';

/// Blocking send readout.
///
/// The steps are not decoration: each line corresponds to work that actually
/// runs, and the dialog will not dismiss until both the animation and the
/// submission have finished. Someone filing a report under duress should be
/// able to see exactly what her phone did.
Future<Incident?> runTransmit(BuildContext context, Future<Incident> future) {
  return showDialog<Incident>(
    context: context,
    barrierDismissible: false,
    barrierColor: KC.text.withValues(alpha: 0.32),
    builder: (_) => _TransmitDialog(future: future),
  );
}

class _TransmitDialog extends StatefulWidget {
  const _TransmitDialog({required this.future});

  final Future<Incident> future;

  @override
  State<_TransmitDialog> createState() => _TransmitDialogState();
}

class _TransmitDialogState extends State<_TransmitDialog> {
  static const _steps = [
    'Creating your private code',
    'Removing anything that identifies you',
    'Sealing what you wrote',
    'Handing it to the case queue',
  ];

  int _step = 0;
  Timer? _timer;
  Incident? _result;
  Object? _error;

  @override
  void initState() {
    super.initState();

    _timer = Timer.periodic(const Duration(milliseconds: 380), (t) {
      if (_step >= _steps.length - 1) {
        t.cancel();
        return;
      }
      setState(() => _step++);
    });

    widget.future.then(
      (incident) {
        _result = incident;
        _finish();
      },
      onError: (Object e) {
        _error = e;
        _finish();
      },
    );
  }

  /// Holds the readout on screen for the remaining step animation so the last
  /// line is never a flash the user cannot read.
  void _finish() {
    final remaining = (_steps.length - 1 - _step).clamp(0, _steps.length);
    Future<void>.delayed(Duration(milliseconds: 380 * remaining + 320), () {
      if (!mounted) return;
      _timer?.cancel();
      Navigator.of(context).pop(_error == null ? _result : null);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 320,
        padding: const EdgeInsets.all(KSpace.xl),
        decoration: BoxDecoration(
          color: KC.surface,
          borderRadius: KRadius.rXl,
          boxShadow: KShadow.lift,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sending', style: KType.serif(size: 20)),
            const SizedBox(height: KSpace.lg),
            for (var i = 0; i < _steps.length; i++)
              AnimatedOpacity(
                duration: const Duration(milliseconds: 220),
                opacity: i <= _step ? 1 : 0.3,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: KSpace.sm),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 24,
                        child: i < _step
                            ? const Icon(Icons.check_circle_rounded,
                                size: 18, color: KC.calm)
                            : i == _step
                                ? const SizedBox(
                                    width: 15,
                                    height: 15,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: KC.primary),
                                  )
                                : const Icon(Icons.circle_outlined,
                                    size: 15, color: KC.faint),
                      ),
                      const SizedBox(width: KSpace.md),
                      Expanded(
                        child: Text(
                          _steps[i],
                          style: KType.sans(
                            size: 13.5,
                            weight: i == _step ? FontWeight.w600 : FontWeight.w400,
                            color: i <= _step ? KC.text : KC.faint,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
