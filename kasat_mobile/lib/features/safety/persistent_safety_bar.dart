import 'package:flutter/material.dart';

import '../../app.dart';
import '../../data/settings_store.dart';
import '../../theme/kasat_theme.dart';
import '../danger/danger_countdown_sheet.dart';

/// Persistent safety strip rendered at the top of every screen in Kasat.
///
/// Houses two critical controls reachable from anywhere:
/// 1. Danger trigger:
///    - `DangerBarMode.visible` (default): High-contrast "I'M IN DANGER" button.
///    - `DangerBarMode.discreet`: Small unlabeled dot triggered by a long-press
///      gesture so anyone glancing at her phone cannot tell what the app is.
/// 2. "Quick exit" button that wipes in-memory form state, locks the PIN
///    session, and exits straight to the device Home Screen (leaving zero
///    browser history).
class PersistentSafetyBar extends StatelessWidget {
  const PersistentSafetyBar({
    super.key,
    required this.onDangerPressed,
    required this.onQuickExitPressed,
  });

  static const dangerButtonKey = Key('im-in-danger-button');
  static const discreetDangerDotKey = Key('discreet-danger-dot');
  static const stopLocationButtonKey = Key('stop-live-location-button');
  static const quickExitButtonKey = Key('quick-exit-button');
  static const approachPromptCardKey = Key('officer-approach-prompt-card');
  static const canComeOutButtonKey = Key('approach-can-come-out-button');
  static const doNotKnockButtonKey = Key('approach-do-not-knock-button');

  final VoidCallback onDangerPressed;
  final VoidCallback onQuickExitPressed;

  @override
  Widget build(BuildContext context) {
    final scope = KasatScope.of(context);
    final discreet = scope.settings.dangerBarMode == DangerBarMode.discreet;

    return ListenableBuilder(
      listenable: Listenable.merge([scope.danger, scope.i18n]),
      builder: (context, _) {
        final i18n = scope.i18n;
        final active = scope.danger.isLiveLocationActive;
        final mins = scope.danger.remainingWindow.inMinutes + 1;
        final showRedActive = active && !discreet;
        final officerArrived = active && scope.danger.hasOfficerArrived;
        final currentResponse = scope.danger.approachResponse;

        return Material(
          color: showRedActive ? const Color(0xFF281113) : KC.surface,
          child: SafeArea(
            bottom: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: KSpace.md,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: showRedActive ? KC.urgent : KC.border,
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      if (!active)
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: discreet
                                ? GestureDetector(
                                    key: dangerButtonKey,
                                    behavior: HitTestBehavior.opaque,
                                    onLongPress: onDangerPressed,
                                    child: Container(
                                      key: discreetDangerDotKey,
                                      width: 32,
                                      height: 28,
                                      alignment: Alignment.centerLeft,
                                      padding: const EdgeInsets.only(left: 4),
                                      child: Container(
                                        width: 9,
                                        height: 9,
                                        decoration: BoxDecoration(
                                          color:
                                              KC.muted.withValues(alpha: 0.55),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                  )
                                : GestureDetector(
                                    key: dangerButtonKey,
                                    onTap: onDangerPressed,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: KSpace.md,
                                        vertical: 7,
                                      ),
                                      decoration: const BoxDecoration(
                                        color: KC.urgent,
                                        borderRadius: KRadius.rPill,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.warning_amber_rounded,
                                            size: 16,
                                            color: Colors.white,
                                          ),
                                          const SizedBox(width: 6),
                                          Flexible(
                                            child: Text(
                                              i18n.t('safety.danger'),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: KType.sans(
                                                size: 12,
                                                weight: FontWeight.w700,
                                                color: Colors.white,
                                              ).copyWith(letterSpacing: 0.4),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                          ),
                        )
                      else
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: discreet ? KC.calm : KC.urgent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  discreet
                                      ? 'Sync active (${mins}m)'
                                      : 'Live GPS active (${mins}m left)',
                                  overflow: TextOverflow.ellipsis,
                                  style: KType.sans(
                                    size: 12,
                                    weight: FontWeight.w600,
                                    color:
                                        showRedActive ? Colors.white : KC.muted,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                key: stopLocationButtonKey,
                                onTap: () => scope.danger.stopLiveLocation(),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: showRedActive
                                        ? Colors.white.withValues(alpha: 0.16)
                                        : KC.surfaceAlt,
                                    borderRadius: KRadius.rPill,
                                    border: showRedActive
                                        ? null
                                        : Border.all(color: KC.border),
                                  ),
                                  child: Text(
                                    discreet ? 'Stop' : 'Stop sharing',
                                    style: KType.sans(
                                      size: 11.5,
                                      weight: FontWeight.w700,
                                      color:
                                          showRedActive ? Colors.white : KC.text,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(width: KSpace.sm),
                      GestureDetector(
                        key: quickExitButtonKey,
                        onTap: onQuickExitPressed,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: discreet ? KSpace.sm : KSpace.md,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: showRedActive
                                ? Colors.white.withValues(alpha: 0.14)
                                : KC.surfaceAlt,
                            borderRadius: KRadius.rPill,
                            border: Border.all(
                              color: showRedActive
                                  ? Colors.white.withValues(alpha: 0.25)
                                  : KC.borderStrong,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.exit_to_app_rounded,
                                size: 15,
                                color: showRedActive ? Colors.white : KC.text,
                              ),
                              if (!discreet) ...[
                                const SizedBox(width: 5),
                                Text(
                                  i18n.t('safety.quickExit'),
                                  style: KType.sans(
                                    size: 12,
                                    weight: FontWeight.w600,
                                    color:
                                        showRedActive ? Colors.white : KC.text,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (officerArrived)
                  Container(
                    key: approachPromptCardKey,
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(
                      KSpace.md,
                      KSpace.sm,
                      KSpace.md,
                      KSpace.md,
                    ),
                    decoration: const BoxDecoration(
                      color: Color(0xFF1A1416),
                      border: Border(
                        bottom: BorderSide(color: KC.urgent, width: 1.5),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.shield_outlined,
                              size: 17,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                currentResponse == 'can_come_out'
                                    ? 'Sent to officer: You can come out'
                                    : currentResponse ==
                                            'abuser_present_do_not_knock'
                                        ? 'Sent to officer: He is here — do not knock'
                                        : 'Officer has arrived nearby — tap silently:',
                                style: KType.sans(
                                  size: 13,
                                  weight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: KSpace.sm),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                key: canComeOutButtonKey,
                                onTap: () => scope.danger
                                    .respondToOfficerApproach('can_come_out'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: KSpace.sm,
                                    vertical: 14,
                                  ),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: currentResponse == 'can_come_out'
                                        ? const Color(0xFF1B5E20)
                                        : const Color(0xFF2E7D32),
                                    borderRadius: KRadius.rMd,
                                    border: Border.all(
                                      color: currentResponse == 'can_come_out'
                                          ? Colors.white
                                          : Colors.white.withValues(alpha: 0.3),
                                      width: currentResponse == 'can_come_out'
                                          ? 2
                                          : 1,
                                    ),
                                  ),
                                  child: Text(
                                    'I can come out',
                                    textAlign: TextAlign.center,
                                    style: KType.sans(
                                      size: 14,
                                      weight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: KSpace.sm),
                            Expanded(
                              child: GestureDetector(
                                key: doNotKnockButtonKey,
                                onTap: () =>
                                    scope.danger.respondToOfficerApproach(
                                  'abuser_present_do_not_knock',
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: KSpace.sm,
                                    vertical: 14,
                                  ),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: currentResponse ==
                                            'abuser_present_do_not_knock'
                                        ? const Color(0xFF8E1B1B)
                                        : KC.urgent,
                                    borderRadius: KRadius.rMd,
                                    border: Border.all(
                                      color: currentResponse ==
                                              'abuser_present_do_not_knock'
                                          ? Colors.white
                                          : Colors.white.withValues(alpha: 0.3),
                                      width: currentResponse ==
                                              'abuser_present_do_not_knock'
                                          ? 2
                                          : 1,
                                    ),
                                  ),
                                  child: Text(
                                    'He is here — do not knock',
                                    textAlign: TextAlign.center,
                                    style: KType.sans(
                                      size: 14,
                                      weight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  static void openDangerSheet(BuildContext context) {
    DangerCountdownSheet.show(context);
  }
}
