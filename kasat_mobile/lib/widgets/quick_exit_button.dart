import 'package:flutter/material.dart';

import '../core/quick_exit.dart';
import '../theme/kasat_theme.dart';

/// Floating "Leave" pill, rendered above every route.
///
/// It sits in the app's builder rather than inside a screen so it survives
/// navigation and stays on top of sheets and dialogs. Styled to read as a
/// normal close affordance — a red panic button would itself be evidence of
/// what the app is.
class QuickExitButton extends StatelessWidget {
  const QuickExitButton({super.key, required this.controller});

  final QuickExitController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: controller.visible,
      builder: (context, visible, _) {
        if (!visible) return const SizedBox.shrink();

        return Positioned(
          right: KSpace.lg,
          bottom: MediaQuery.of(context).padding.bottom + 74,
          child: Material
            (
            color: KC.surface,
            borderRadius: KRadius.rPill,
            elevation: 0,
            child: InkWell(
              borderRadius: KRadius.rPill,
              onTap: controller.trigger,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: KSpace.lg, vertical: 11),
                decoration: BoxDecoration(
                  borderRadius: KRadius.rPill,
                  border: Border.all(color: KC.borderStrong),
                  boxShadow: KShadow.lift,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.close_rounded, size: 17, color: KC.secondary),
                    const SizedBox(width: 7),
                    Text(
                      'Leave',
                      style: KType.sans(
                        size: 14,
                        weight: FontWeight.w600,
                        color: KC.secondary,
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
