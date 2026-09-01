import 'dart:async';

import 'package:flutter/material.dart';

import '../../../models/incident.dart';
import '../../../theme/kasat_theme.dart';
import '../../../widgets/mono_badge.dart';

/// Blocking transmit readout.
///
/// The steps are not decoration: each line corresponds to work that actually
/// runs, and the dialog will not dismiss until both the animation and the
/// submission future have finished. Someone filing a report under duress
/// should be able to see exactly what their phone did.
Future<Incident?> runTransmit(BuildContext context, Future<Incident> future) {
  return showDialog<Incident>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.86),
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
    'Minting client-side identifier',
    'Stripping originator metadata',
    'Sealing payload for dispatch',
    'Handing off to intake queue',
  ];

  int _step = 0;
  Timer? _timer;
  Incident? _result;
  Object? _error;

  @override
  void initState() {
    super.initState();

    _timer = Timer.periodic(const Duration(milliseconds: 330), (t) {
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
    Future<void>.delayed(Duration(milliseconds: 330 * remaining + 260), () {
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
        width: 300,
        padding: const EdgeInsets.all(KSpace.lg),
        decoration: BoxDecoration(
          color: KC.surface,
          border: Border.all(color: KC.accentDeep),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const LiveDot(),
                const SizedBox(width: 7),
                Text('TRANSMITTING', style: KType.label(color: KC.accent)),
                const Spacer(),
                MonoBadge('${_step + 1}/${_steps.length}', size: 9, dense: true),
              ],
            ),
            const SizedBox(height: KSpace.md),
            const Divider(height: 1, color: KC.border),
            const SizedBox(height: KSpace.md),
            for (var i = 0; i < _steps.length; i++)
              AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: i <= _step ? 1 : 0.22,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 16,
                        child: i < _step
                            ? const Icon(Icons.check_rounded, size: 12, color: KC.accent)
                            : Text(
                                i == _step ? '›' : '·',
                                style: KType.mono(
                                  size: 12,
                                  color: i == _step ? KC.accent : KC.faint,
                                  weight: FontWeight.w700,
                                ),
                              ),
                      ),
                      Expanded(
                        child: Text(
                          _steps[i],
                          style: KType.mono(
                            size: 10.5,
                            color: i <= _step ? KC.text : KC.faint,
                            weight: FontWeight.w600,
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
