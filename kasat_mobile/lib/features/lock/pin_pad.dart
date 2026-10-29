import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/kasat_theme.dart';

/// Progress dots for a PIN of [length].
class PinDots extends StatelessWidget {
  const PinDots({
    super.key,
    required this.filled,
    required this.length,
    this.error = false,
  });

  final int filled;
  final int length;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final color = error ? KC.urgent : KC.primary;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < length; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            margin: const EdgeInsets.symmetric(horizontal: 7),
            width: 13,
            height: 13,
            decoration: BoxDecoration(
              color: i < filled ? color : Colors.transparent,
              border: Border.all(
                color: i < filled ? color : KC.borderStrong,
                width: 1.8,
              ),
              shape: BoxShape.circle,
            ),
          ),
      ],
    );
  }
}

/// In-app numeric keypad.
///
/// The system keyboard is avoided on purpose: it would surface the survivor's
/// typing history and predictive suggestions, and a numeric row on a warm
/// screen looks far less like a security prompt.
class PinPad extends StatelessWidget {
  const PinPad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    this.trailing,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  /// Optional biometric affordance, shown in the bottom-left slot.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [for (final d in row) _Key(label: d, onTap: () => onDigit(d))],
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(width: 84, height: 68, child: Center(child: trailing)),
            _Key(label: '0', onTap: () => onDigit('0')),
            SizedBox(
              width: 84,
              height: 68,
              child: Center(
                child: IconButton(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    onBackspace();
                  },
                  icon: const Icon(Icons.backspace_outlined, size: 22, color: KC.muted),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 84,
      height: 68,
      child: Center(
        child: Material(
          color: KC.surface,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () {
              HapticFeedback.selectionClick();
              onTap();
            },
            child: Container(
              width: 62,
              height: 62,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: KC.border),
              ),
              child: Text(label, style: KType.serif(size: 24, weight: FontWeight.w500)),
            ),
          ),
        ),
      ),
    );
  }
}
