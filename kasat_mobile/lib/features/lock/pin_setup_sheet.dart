import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app.dart';
import '../../data/settings_store.dart';
import '../../theme/kasat_theme.dart';
import 'lock_screen.dart';
import 'pin_pad.dart';

/// Prompts the survivor to create or enter a 6-digit PIN only when she saves
/// something on-device or opens saved reports / case history / tracking codes.
///
/// Opening the app and submitting a new report never hits a login or PIN wall.
abstract final class PinGuard {
  /// Called the first time she saves anything on-device (a report, her optional
  /// local profile, etc.). If a PIN already exists, returns true immediately.
  static Future<bool> ensurePinForSaving(
    BuildContext context, {
    String reason =
        'Choose a 6-digit code to lock your saved reports and tracking codes on this phone.',
  }) async {
    final scope = KasatScope.of(context);
    if (scope.settings.hasPin) {
      scope.unlockPinSession();
      return true;
    }
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        fullscreenDialog: true,
        builder: (_) => PinSetupScreen(
          settings: scope.settings,
          reason: reason,
        ),
      ),
    );
    if (created == true) {
      scope.unlockPinSession();
      return true;
    }
    return false;
  }

  /// Called before showing saved reports, case history, or tracking codes.
  static Future<bool> ensureUnlocked(BuildContext context) async {
    final scope = KasatScope.of(context);
    if (scope.isPinSessionUnlocked && scope.settings.hasPin) {
      return true;
    }
    if (!scope.settings.hasPin) {
      return ensurePinForSaving(
        context,
        reason:
            'Set a 6-digit code so nobody else who picks up this phone can see your saved cases or tracking codes.',
      );
    }
    final unlocked = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        fullscreenDialog: true,
        builder: (navCtx) => LockScreen(
          settings: scope.settings,
          headline: 'Protected history',
          onUnlocked: () => Navigator.of(navCtx).pop(true),
        ),
      ),
    );
    if (unlocked == true) {
      scope.unlockPinSession();
      return true;
    }
    return false;
  }
}

class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({
    super.key,
    required this.settings,
    this.reason =
        'Choose a 6-digit code so if someone picks up your phone, they cannot see your saved reports list.',
  });

  static const warningBannerKey = Key('pin-setup-warning-banner');

  final SettingsStore settings;
  final String reason;

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  String _pin = '';
  String _confirm = '';
  bool _confirming = false;
  String? _error;

  void _pushDigit(String digit) {
    setState(() {
      _error = null;
      if (!_confirming) {
        if (_pin.length < SettingsStore.pinLength) _pin += digit;
        if (_pin.length == SettingsStore.pinLength) {
          HapticFeedback.selectionClick();
          _confirming = true;
        }
      } else {
        if (_confirm.length < SettingsStore.pinLength) _confirm += digit;
        if (_confirm.length == SettingsStore.pinLength) _checkMatch();
      }
    });
  }

  Future<void> _checkMatch() async {
    if (_pin == _confirm) {
      HapticFeedback.mediumImpact();
      await widget.settings.setPin(_pin);
      if (!mounted) return;
      Navigator.of(context).pop(true);
      return;
    }
    HapticFeedback.vibrate();
    setState(() {
      _pin = '';
      _confirm = '';
      _confirming = false;
      _error = 'Those codes did not match. Let\u2019s try again.';
    });
  }

  void _backspace() {
    setState(() {
      _error = null;
      if (_confirming) {
        if (_confirm.isEmpty) {
          _confirming = false;
          if (_pin.isNotEmpty) {
            _pin = _pin.substring(0, _pin.length - 1);
          }
        } else {
          _confirm = _confirm.substring(0, _confirm.length - 1);
        }
      } else if (_pin.isNotEmpty) {
        _pin = _pin.substring(0, _pin.length - 1);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KC.canvas,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        KSpace.sm,
                        KSpace.xs,
                        KSpace.md,
                        0,
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            icon: const Icon(
                              Icons.close_rounded,
                              color: KC.muted,
                            ),
                            tooltip: 'Cancel',
                          ),
                          const Spacer(),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        KSpace.xl,
                        KSpace.xs,
                        KSpace.xl,
                        0,
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              color: KC.primarySoft,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.lock_outline_rounded,
                              size: 22,
                              color: KC.primary,
                            ),
                          ),
                          const SizedBox(height: KSpace.sm),
                          Text(
                            _confirming
                                ? 'Once more'
                                : 'Protect your saved history',
                            style: KType.serif(size: 24),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: KSpace.xs),
                          Text(
                            _error ??
                                (_confirming
                                    ? 'Enter the same six digits again to confirm.'
                                    : widget.reason),
                            textAlign: TextAlign.center,
                            style: KType.sans(
                              size: 13,
                              color: _error != null ? KC.urgent : KC.muted,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: KSpace.sm),
                          Container(
                            key: PinSetupScreen.warningBannerKey,
                            padding: const EdgeInsets.all(KSpace.sm),
                            decoration: BoxDecoration(
                              color: KC.urgentSoft,
                              borderRadius: KRadius.rMd,
                              border: Border.all(
                                color: KC.urgent.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.warning_amber_rounded,
                                  size: 17,
                                  color: KC.urgent,
                                ),
                                const SizedBox(width: KSpace.sm),
                                Expanded(
                                  child: Text(
                                    'Forgetting this PIN means losing access to the '
                                    'saved-reports list on this device. Your written '
                                    'tracking code (KST-…) is the only recovery — you '
                                    'can always type your tracking code directly to '
                                    'check your case without a PIN.',
                                    style: KType.sans(
                                      size: 11.5,
                                      weight: FontWeight.w600,
                                      color: KC.text,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: KSpace.md),
                          PinDots(
                            filled: _confirming ? _confirm.length : _pin.length,
                            length: SettingsStore.pinLength,
                            error: _error != null,
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(height: KSpace.sm),
                    PinPad(onDigit: _pushDigit, onBackspace: _backspace),
                    const SizedBox(height: KSpace.md),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
