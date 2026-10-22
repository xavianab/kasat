import 'package:flutter/material.dart';

import '../../app.dart';
import '../../data/settings_store.dart';
import '../../models/country.dart';
import '../../theme/kasat_theme.dart';
import '../../widgets/kasat_button.dart';
import '../../widgets/panel.dart';
import '../../widgets/soft_backdrop.dart';
import '../accounts/account_setup_view.dart';
import '../lock/pin_setup_sheet.dart';
import '../onboarding/country_picker.dart';

/// Settings screen:
/// 1. Danger button visibility toggle (Full visible bar vs Discreet mode).
/// 2. Optional "Save my details" encrypted on-device profile (NOT a login,
///    never synced to Supabase).
/// 3. 6-digit PIN setup / change for protecting saved reports list on this device.
/// 4. Country selection.
class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  static const saveMyDetailsButtonKey = Key('settings-save-my-details');
  static const dangerModeVisibleKey = Key('danger-mode-visible');
  static const dangerModeDiscreetKey = Key('danger-mode-discreet');

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  Future<void> _openProfileSetup() async {
    final scope = KasatScope.of(context);
    if (scope.identity.hasIdentity) {
      final ok = await PinGuard.ensureUnlocked(context);
      if (!mounted || !ok) return;
    } else {
      final ok = await PinGuard.ensurePinForSaving(
        context,
        reason:
            'Choose a 6-digit code before saving your details on this phone.',
      );
      if (!mounted || !ok) return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const AccountSetupView(),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _changeOrSetPin() async {
    final scope = KasatScope.of(context);
    if (scope.settings.hasPin && !scope.isPinSessionUnlocked) {
      final ok = await PinGuard.ensureUnlocked(context);
      if (!mounted || !ok) return;
    }
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        fullscreenDialog: true,
        builder: (_) => PinSetupScreen(
          settings: scope.settings,
          reason:
              'Choose a 6-digit code to lock your saved reports, tracking codes, and history on this phone.',
        ),
      ),
    );
    if (mounted) {
      scope.unlockPinSession();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = KasatScope.of(context);
    final settings = scope.settings;
    final identity = scope.identity;
    final current = countryByCode(settings.effectiveCountryCode);
    final hasSavedDetails = identity.hasIdentity;

    return Scaffold(
      backgroundColor: KC.canvas,
      body: SoftBackdrop(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  KSpace.sm,
                  KSpace.sm,
                  KSpace.xl,
                  0,
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                      color: KC.muted,
                    ),
                    Text('Settings', style: KType.serif(size: 22)),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(KSpace.xl),
                  children: [
                    KPanel(
                      title: 'Danger button appearance',
                      subtitle: settings.dangerBarMode == DangerBarMode.discreet
                          ? 'Discreet mode: unlabeled dot (press & hold to trigger).'
                          : 'Full visible bar (default): red "I\'M IN DANGER" button.',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Choose how the emergency control appears at the top '
                            'of the screen. Discreet mode hides the red "I\'M IN '
                            'DANGER" bar so someone glancing at your phone cannot '
                            'tell what the app is — press and hold the small '
                            'top-left dot to trigger an emergency alert.',
                            style: KType.sans(
                              size: 13.5,
                              color: KC.muted,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: KSpace.md),
                          _DangerModeOption(
                            optionKey: SettingsView.dangerModeVisibleKey,
                            mode: DangerBarMode.visible,
                            selected:
                                settings.dangerBarMode == DangerBarMode.visible,
                            onTap: () async {
                              await settings.setDangerBarMode(
                                DangerBarMode.visible,
                              );
                              scope.notifySettingsChanged();
                              if (mounted) setState(() {});
                            },
                          ),
                          const SizedBox(height: KSpace.sm),
                          _DangerModeOption(
                            optionKey: SettingsView.dangerModeDiscreetKey,
                            mode: DangerBarMode.discreet,
                            selected:
                                settings.dangerBarMode == DangerBarMode.discreet,
                            onTap: () async {
                              await settings.setDangerBarMode(
                                DangerBarMode.discreet,
                              );
                              scope.notifySettingsChanged();
                              if (mounted) setState(() {});
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: KSpace.md),
                    KPanel(
                      title: 'Save my details (optional)',
                      subtitle:
                          'Optional. Stays encrypted on this phone only — never synced to a server.',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Kasat never requires an account or login. If you '
                            'choose to save your name and phone or email here, '
                            'it is stored encrypted on your phone for faster '
                            'future reports if you ever decide to reveal your '
                            'identity to police on a case.',
                            style: KType.sans(
                              size: 13.5,
                              color: KC.muted,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: KSpace.md),
                          KButton(
                            key: SettingsView.saveMyDetailsButtonKey,
                            label: hasSavedDetails
                                ? 'Edit or clear saved details'
                                : 'Save my details on this phone',
                            kind: KButtonKind.secondary,
                            icon: Icons.badge_outlined,
                            compact: true,
                            onPressed: _openProfileSetup,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: KSpace.md),
                    KPanel(
                      title: 'History & tracking code lock (PIN)',
                      subtitle: settings.hasPin
                          ? '6-digit code active for saved cases and tracking codes.'
                          : 'No PIN set yet. You will be asked when you first save.',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Filing a new report never asks for a PIN. Your '
                            '6-digit code locks saved reports, case history, '
                            'and tracking codes so nobody else who picks up '
                            'your phone can see them.',
                            style: KType.sans(
                              size: 13.5,
                              color: KC.muted,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: KSpace.md),
                          KButton(
                            label: settings.hasPin
                                ? 'Change 6-digit PIN'
                                : 'Set 6-digit PIN now',
                            kind: KButtonKind.soft,
                            icon: Icons.lock_outline_rounded,
                            compact: true,
                            onPressed: _changeOrSetPin,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: KSpace.md),
                    KPanel(
                      title: 'Your country',
                      subtitle: current == null
                          ? 'Used for help lines and where a report is sent.'
                          : '${current.flag}  ${current.name}',
                      child: CountryPicker(
                        selectedCode: settings.effectiveCountryCode,
                        onSelect: (code) async {
                          await settings.setCountryCode(code);
                          if (mounted) setState(() {});
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DangerModeOption extends StatelessWidget {
  const _DangerModeOption({
    required this.optionKey,
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final Key optionKey;
  final DangerBarMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: optionKey,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(KSpace.md),
        decoration: BoxDecoration(
          color: selected ? KC.primarySoft : KC.surfaceAlt,
          borderRadius: KRadius.rMd,
          border: Border.all(
            color: selected ? KC.primary : KC.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              size: 20,
              color: selected ? KC.primary : KC.muted,
            ),
            const SizedBox(width: KSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mode.label,
                    style: KType.sans(
                      size: 13.5,
                      weight: FontWeight.w600,
                      color: KC.text,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    mode.blurb,
                    style: KType.sans(
                      size: 12.5,
                      color: KC.muted,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
