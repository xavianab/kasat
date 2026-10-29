import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/biometrics.dart';
import '../../data/settings_store.dart';
import '../../theme/kasat_theme.dart';
import '../../widgets/soft_backdrop.dart';
import 'pin_pad.dart';

/// The gate in front of everything.
///
/// Shows no app name, no logo, and no hint about what it protects — someone who
/// picks up the handset and opens the app learns only that there is a code.
class LockScreen extends StatefulWidget {
  const LockScreen({
    super.key,
    required this.settings,
    required this.onUnlocked,
    this.headline = 'Welcome back',
  });

  final SettingsStore settings;
  final VoidCallback onUnlocked;
  final String headline;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String _entry = '';
  bool _error = false;
  bool _biometricAvailable = false;
  int _attempts = 0;

  @override
  void initState() {
    super.initState();
    _prepareBiometrics();
  }

  Future<void> _prepareBiometrics() async {
    if (!widget.settings.biometricEnabled) return;
    final available = await Biometrics.available();
    if (!mounted) return;
    setState(() => _biometricAvailable = available);
    if (available) await _tryBiometric();
  }

  Future<void> _tryBiometric() async {
    // A false here means cancelled, failed, or unavailable. All three fall
    // through to the PIN rather than blocking the way in.
    final ok = await Biometrics.authenticate();
    if (ok && mounted) widget.onUnlocked();
  }

  void _push(String digit) {
    if (_entry.length >= SettingsStore.pinLength) return;
    setState(() {
      _entry += digit;
      _error = false;
    });
    if (_entry.length == SettingsStore.pinLength) _submit();
  }

  void _submit() {
    if (widget.settings.verifyPin(_entry)) {
      HapticFeedback.mediumImpact();
      widget.onUnlocked();
      return;
    }
    HapticFeedback.vibrate();
    setState(() {
      _error = true;
      _entry = '';
      _attempts++;
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
              const Spacer(flex: 2),
              Container(
                width: 62,
                height: 62,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: KC.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: KC.border),
                  boxShadow: KShadow.card,
                ),
                child: const Icon(Icons.spa_outlined, size: 28, color: KC.primary),
              ),
              const SizedBox(height: KSpace.xl),
              Text(widget.headline, style: KType.serif(size: 26)),
              const SizedBox(height: KSpace.sm),
              Text(
                _error ? 'That code did not match' : 'Enter your code',
                style: KType.sans(
                  size: 14,
                  color: _error ? KC.urgent : KC.muted,
                ),
              ),
              const SizedBox(height: KSpace.xl),
              PinDots(
                filled: _entry.length,
                length: SettingsStore.pinLength,
                error: _error,
              ),
              if (_attempts >= 3) ...[
                const SizedBox(height: KSpace.lg),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: KSpace.xxl),
                  child: Text(
                    'There is no way to recover this code. It was never sent '
                    'anywhere, so nobody can reset it for you.',
                    textAlign: TextAlign.center,
                    style: KType.sans(size: 12.5, color: KC.muted, height: 1.5),
                  ),
                ),
              ],
              const Spacer(),
              PinPad(
                onDigit: _push,
                onBackspace: () => setState(() {
                  if (_entry.isNotEmpty) {
                    _entry = _entry.substring(0, _entry.length - 1);
                  }
                  _error = false;
                }),
                trailing: _biometricAvailable
                    ? IconButton(
                        onPressed: _tryBiometric,
                        icon: const Icon(Icons.face_retouching_natural_outlined,
                            size: 26, color: KC.primary),
                      )
                    : null,
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
