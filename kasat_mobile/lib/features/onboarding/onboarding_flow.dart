import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/biometrics.dart';
import '../../data/settings_store.dart';
import '../../platform/app_disguise_channel.dart';
import '../../theme/kasat_theme.dart';
import '../../widgets/kasat_button.dart';
import '../../widgets/panel.dart';
import '../../widgets/soft_backdrop.dart';
import '../lock/pin_pad.dart';
import 'country_picker.dart';

/// First-launch setup, in the order that matters: where she is, then how she
/// gets back in, then how the app presents itself on her home screen.
///
/// Country comes first because everything downstream — which hotlines she is
/// shown, which crisis lines appear on the banner, which portal her report
/// routes to — is keyed off it.
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key, required this.settings, required this.onComplete});

  final SettingsStore settings;
  final VoidCallback onComplete;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  int _step = 0;

  String? _country;
  String _pin = '';
  String _confirm = '';
  bool _confirming = false;
  String? _pinError;
  bool _biometricSupported = false;
  bool _biometricChosen = false;
  AppDisguise _disguise = AppDisguise.none;
  bool _disguiseSupported = false;
  String? _disguiseNote;

  static const _totalSteps = 4;

  @override
  void initState() {
    super.initState();
    _probeCapabilities();
  }

  Future<void> _probeCapabilities() async {
    final biometric = await Biometrics.available();
    final disguise = await AppDisguiseChannel.isSupported();
    if (!mounted) return;
    setState(() {
      _biometricSupported = biometric;
      _disguiseSupported = disguise;
    });
  }

  void _next() => setState(() => _step++);

  Future<void> _finish() async {
    await widget.settings.setCountryCode(_country!);
    await widget.settings.setPin(_pin);
    await widget.settings.setBiometricEnabled(_biometricChosen);
    await widget.settings.setDisguise(_disguise);

    if (_disguise != AppDisguise.none) {
      await AppDisguiseChannel.apply(_disguise);
    }
    await widget.settings.completeOnboarding();
    widget.onComplete();
  }

  // ------------------------------------------------------------------- PIN

  void _pushDigit(String digit) {
    setState(() {
      _pinError = null;
      if (!_confirming) {
        if (_pin.length < SettingsStore.pinLength) _pin += digit;
        if (_pin.length == SettingsStore.pinLength) _confirming = true;
      } else {
        if (_confirm.length < SettingsStore.pinLength) _confirm += digit;
        if (_confirm.length == SettingsStore.pinLength) _checkMatch();
      }
    });
  }

  void _checkMatch() {
    if (_pin == _confirm) {
      HapticFeedback.mediumImpact();
      _next();
      return;
    }
    HapticFeedback.vibrate();
    _pin = '';
    _confirm = '';
    _confirming = false;
    _pinError = 'Those codes did not match. Let\u2019s try again.';
  }

  void _backspace() {
    setState(() {
      _pinError = null;
      if (_confirming) {
        if (_confirm.isEmpty) {
          _confirming = false;
          _pin = _pin.substring(0, _pin.length - 1);
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
      body: SoftBackdrop(
        child: SafeArea(
          child: Column(
            children: [
              _Progress(step: _step, total: _totalSteps),
              Expanded(
                child: switch (_step) {
                  0 => _CountryStep(
                      selected: _country,
                      onSelect: (code) => setState(() => _country = code),
                      onContinue: _country == null ? null : _next,
                    ),
                  1 => _PinStep(
                      pin: _pin,
                      confirm: _confirm,
                      confirming: _confirming,
                      error: _pinError,
                      onDigit: _pushDigit,
                      onBackspace: _backspace,
                    ),
                  2 => _BiometricStep(
                      supported: _biometricSupported,
                      chosen: _biometricChosen,
                      onChanged: (v) => setState(() => _biometricChosen = v),
                      onContinue: _next,
                    ),
                  _ => _DisguiseStep(
                      supported: _disguiseSupported,
                      selected: _disguise,
                      note: _disguiseNote,
                      onSelect: (d) => setState(() {
                        _disguise = d;
                        _disguiseNote = d == AppDisguise.none
                            ? null
                            : 'iOS shows a confirmation alert when the icon '
                                'changes, and the name under the icon cannot be '
                                'changed by an app.';
                      }),
                      onFinish: _finish,
                    ),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.step, required this.total});

  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(KSpace.xl, KSpace.lg, KSpace.xl, 0),
      child: Row(
        children: [
          for (var i = 0; i < total; i++)
            Expanded(
              child: Container(
                height: 4,
                margin: EdgeInsets.only(right: i == total - 1 ? 0 : 6),
                decoration: BoxDecoration(
                  color: i <= step ? KC.primary : KC.border,
                  borderRadius: KRadius.rPill,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StepScaffold extends StatelessWidget {
  const _StepScaffold({
    required this.title,
    required this.blurb,
    required this.child,
    required this.footer,
  });

  final String title;
  final String blurb;
  final Widget child;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(KSpace.xl, KSpace.xl, KSpace.xl, KSpace.lg),
            children: [
              Text(title, style: KType.serif(size: 28, height: 1.2)),
              const SizedBox(height: KSpace.md),
              Text(blurb, style: KType.sans(size: 14.5, color: KC.muted, height: 1.55)),
              const SizedBox(height: KSpace.xl),
              child,
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(KSpace.xl, 0, KSpace.xl, KSpace.lg),
          child: footer,
        ),
      ],
    );
  }
}

class _CountryStep extends StatelessWidget {
  const _CountryStep({
    required this.selected,
    required this.onSelect,
    required this.onContinue,
  });

  final String? selected;
  final ValueChanged<String> onSelect;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    return _StepScaffold(
      title: 'Where are you?',
      blurb: 'This decides which police, government and support lines you are '
          'shown, and which office your report reaches. It stays on this phone.',
      footer: KButton(label: 'Continue', onPressed: onContinue),
      child: CountryPicker(selectedCode: selected, onSelect: onSelect),
    );
  }
}

class _PinStep extends StatelessWidget {
  const _PinStep({
    required this.pin,
    required this.confirm,
    required this.confirming,
    required this.error,
    required this.onDigit,
    required this.onBackspace,
  });

  final String pin;
  final String confirm;
  final bool confirming;
  final String? error;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(KSpace.xl, KSpace.xl, KSpace.xl, 0),
          child: Column(
            children: [
              Text(
                confirming ? 'Once more' : 'Choose a code',
                style: KType.serif(size: 28),
              ),
              const SizedBox(height: KSpace.md),
              Text(
                error ??
                    (confirming
                        ? 'Enter the same six digits again.'
                        : 'Six digits, asked for every time the app opens. '
                            'Pick something you would not use elsewhere.'),
                textAlign: TextAlign.center,
                style: KType.sans(
                  size: 14,
                  color: error != null ? KC.urgent : KC.muted,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: KSpace.xl),
              PinDots(
                filled: confirming ? confirm.length : pin.length,
                length: SettingsStore.pinLength,
                error: error != null,
              ),
            ],
          ),
        ),
        const Spacer(),
        PinPad(onDigit: onDigit, onBackspace: onBackspace),
        const SizedBox(height: KSpace.lg),
      ],
    );
  }
}

class _BiometricStep extends StatelessWidget {
  const _BiometricStep({
    required this.supported,
    required this.chosen,
    required this.onChanged,
    required this.onContinue,
  });

  final bool supported;
  final bool chosen;
  final ValueChanged<bool> onChanged;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return _StepScaffold(
      title: 'Faster way in',
      blurb: supported
          ? 'Use Face ID or Touch ID instead of typing your code. Your code '
              'still works, and still opens the app if this fails.'
          : 'This phone has no Face ID or Touch ID set up, so your code will '
              'be the way in. You can revisit this later.',
      footer: KButton(label: 'Continue', onPressed: onContinue),
      child: !supported
          ? const SizedBox.shrink()
          : KPanel(
              padding: const EdgeInsets.all(KSpace.md),
              child: SwitchListTile.adaptive(
                value: chosen,
                onChanged: onChanged,
                activeThumbColor: KC.primary,
                contentPadding: const EdgeInsets.symmetric(horizontal: KSpace.sm),
                title: Text(
                  'Use Face ID or Touch ID',
                  style: KType.sans(size: 15, weight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Nothing biometric leaves this phone.',
                  style: KType.sans(size: 12.5, color: KC.muted),
                ),
              ),
            ),
    );
  }
}

class _DisguiseStep extends StatelessWidget {
  const _DisguiseStep({
    required this.supported,
    required this.selected,
    required this.note,
    required this.onSelect,
    required this.onFinish,
  });

  final bool supported;
  final AppDisguise selected;
  final String? note;
  final ValueChanged<AppDisguise> onSelect;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    return _StepScaffold(
      title: 'How it looks on your phone',
      blurb: supported
          ? 'Choose the icon that appears on your home screen. You can change '
              'this whenever you like.'
          : 'This phone cannot change app icons, so it will appear as Kasat.',
      footer: KButton(label: 'Finish setup', icon: Icons.check_rounded, onPressed: onFinish),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (supported)
            for (final option in AppDisguise.values)
              Padding(
                padding: const EdgeInsets.only(bottom: KSpace.sm),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onSelect(option),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.all(KSpace.lg),
                    decoration: BoxDecoration(
                      color: option == selected ? KC.primarySoft : KC.surface,
                      border: Border.all(
                        color: option == selected ? KC.primary : KC.border,
                        width: option == selected ? 1.8 : 1.4,
                      ),
                      borderRadius: KRadius.rMd,
                    ),
                    child: Row(
                      children: [
                        _IconPreview(disguise: option),
                        const SizedBox(width: KSpace.lg),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                option.label,
                                style: KType.sans(size: 16, weight: FontWeight.w600),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                option.blurb,
                                style: KType.sans(size: 12.5, color: KC.muted),
                              ),
                            ],
                          ),
                        ),
                        if (option == selected)
                          const Icon(Icons.check_circle_rounded,
                              color: KC.primary, size: 24),
                      ],
                    ),
                  ),
                ),
              ),
          if (note != null) ...[
            const SizedBox(height: KSpace.sm),
            KNote(
              title: 'Two things to know',
              body: note!,
              icon: Icons.info_outline_rounded,
              color: KC.secondary,
            ),
          ],
        ],
      ),
    );
  }
}

/// Miniature of each home screen icon, drawn rather than loaded — the real
/// assets live in the iOS bundle and are not Flutter assets.
class _IconPreview extends StatelessWidget {
  const _IconPreview({required this.disguise});

  final AppDisguise disguise;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, icon) = switch (disguise) {
      AppDisguise.none => (KC.primarySoft, KC.primary, Icons.spa_outlined),
      AppDisguise.notes => (const Color(0xFFF7C94A), Colors.white, Icons.description),
      AppDisguise.calculator => (const Color(0xFF3A3A3E), Colors.white, Icons.calculate),
    };

    return Container(
      width: 46,
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, borderRadius: KRadius.rSm),
      child: Icon(icon, size: 24, color: fg),
    );
  }
}
