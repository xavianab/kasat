import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Which home screen identity the app presents itself under.
enum AppDisguise {
  none(id: 'NONE', label: 'Kasat', blurb: 'The real name and icon.'),
  notes(id: 'NOTES', label: 'Notes', blurb: 'A plain yellow notepad icon.'),
  calculator(
    id: 'CALCULATOR',
    label: 'Calculator',
    blurb: 'A grey calculator icon.',
  );

  const AppDisguise({required this.id, required this.label, required this.blurb});

  final String id;
  final String label;
  final String blurb;

  /// Asset catalog name the iOS side expects. Null means the primary icon.
  String? get iconName => switch (this) {
        AppDisguise.none => null,
        AppDisguise.notes => 'AltIconNotes',
        AppDisguise.calculator => 'AltIconCalculator',
      };

  static AppDisguise fromId(String? id) => AppDisguise.values.firstWhere(
        (d) => d.id == id,
        orElse: () => AppDisguise.none,
      );
}

/// Local, non-synced preferences: the survivor's country, her lock setup, and
/// her chosen disguise.
///
/// The PIN is never stored, only a salted hash of it, so reading this store
/// off a seized handset does not reveal the code. It still lives in the app's
/// preference plist rather than the Keychain, which is the honest limit of
/// this MVP — see `README.md`.
class SettingsStore {
  static const _countryKey = 'kasat.country.v1';
  static const _pinHashKey = 'kasat.pin_hash.v1';
  static const _pinSaltKey = 'kasat.pin_salt.v1';
  static const _biometricKey = 'kasat.biometric.v1';
  static const _disguiseKey = 'kasat.disguise.v1';
  static const _onboardedKey = 'kasat.onboarded.v1';

  static const pinLength = 6;
  static const _hashRounds = 20000;

  static final _random = Random.secure();

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ---------------------------------------------------------------- country

  String? get countryCode => _prefs.getString(_countryKey);

  Future<void> setCountryCode(String code) => _prefs.setString(_countryKey, code);

  // ------------------------------------------------------------------- lock

  bool get hasPin => _prefs.getString(_pinHashKey) != null;

  bool get biometricEnabled => _prefs.getBool(_biometricKey) ?? false;

  Future<void> setBiometricEnabled(bool value) =>
      _prefs.setBool(_biometricKey, value);

  Future<void> setPin(String pin) async {
    final salt = _newSalt();
    await _prefs.setString(_pinSaltKey, salt);
    await _prefs.setString(_pinHashKey, _hash(pin, salt));
  }

  bool verifyPin(String pin) {
    final stored = _prefs.getString(_pinHashKey);
    final salt = _prefs.getString(_pinSaltKey);
    if (stored == null || salt == null) return false;
    return _constantTimeEquals(stored, _hash(pin, salt));
  }

  // --------------------------------------------------------------- disguise

  AppDisguise get disguise => AppDisguise.fromId(_prefs.getString(_disguiseKey));

  Future<void> setDisguise(AppDisguise disguise) =>
      _prefs.setString(_disguiseKey, disguise.id);

  // ------------------------------------------------------------- onboarding

  bool get onboardingComplete => (_prefs.getBool(_onboardedKey) ?? false) && countryCode != null;

  Future<void> completeOnboarding() => _prefs.setBool(_onboardedKey, true);

  // ------------------------------------------------------------------ crypto

  static String _newSalt() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    return base64Url.encode(bytes);
  }

  /// Iterated SHA-256. A six-digit PIN only has a million possible values, so
  /// the rounds are what make an offline guess against a copied plist cost
  /// something rather than being instant.
  static String _hash(String pin, String salt) {
    var digest = sha256.convert(utf8.encode('$salt|$pin')).bytes;
    for (var i = 1; i < _hashRounds; i++) {
      digest = sha256.convert(digest).bytes;
    }
    return base64Url.encode(digest);
  }

  /// Compares without an early return so a timing measurement cannot walk the
  /// hash one character at a time.
  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}
