import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Drives the always-visible escape hatch.
///
/// [trigger] does two things, and both matter: it tears down every route above
/// the root so an open form, sheet, or dialog cannot be returned to, and it
/// flips the root gate over to the decoy. Whoever takes the handset after the
/// button is pressed finds nothing behind the decoy.
class QuickExitController {
  QuickExitController(this.navigatorKey);

  final GlobalKey<NavigatorState> navigatorKey;

  /// Hidden during onboarding, on the lock screen, and on the decoy itself —
  /// on those screens there is nothing to escape from, and a stray exit button
  /// would only draw attention.
  final visible = ValueNotifier<bool>(false);

  /// Watched by the root gate.
  final decoyActive = ValueNotifier<bool>(false);

  void trigger() {
    HapticFeedback.heavyImpact();
    visible.value = false;
    navigatorKey.currentState?.popUntil((route) => route.isFirst);
    decoyActive.value = true;
  }

  void leaveDecoy() {
    decoyActive.value = false;
  }

  void dispose() {
    visible.dispose();
    decoyActive.dispose();
  }
}
