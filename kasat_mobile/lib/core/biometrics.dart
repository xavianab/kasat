import 'package:local_auth/local_auth.dart';

/// Thin wrapper over `local_auth`.
///
/// Exists so the plugin's API surface is named in one place, and so both
/// callers agree on the important rule: a biometric failure is never fatal.
/// Face ID is a convenience on top of the PIN, and the PIN always works.
abstract final class Biometrics {
  static final _auth = LocalAuthentication();

  /// True only when the handset supports biometrics *and* the survivor has
  /// actually enrolled one.
  static Future<bool> available() async {
    try {
      if (!await _auth.isDeviceSupported()) return false;
      return (await _auth.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        // Rendered in a system dialog that a bystander can read, so it names
        // neither the app nor what it protects.
        localizedReason: 'Unlock to continue',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }
}
