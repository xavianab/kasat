import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/country.dart';

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

/// How the persistent top emergency control is rendered.
enum DangerBarMode {
  visible(
    id: 'VISIBLE',
    label: 'Full visible bar (default)',
    blurb: 'Shows the red "I\'M IN DANGER" button at the top of every screen.',
  ),
  discreet(
    id: 'DISCREET',
    label: 'Discreet mode (unlabeled dot + long-press)',
    blurb:
        'Hides emergency wording so someone glancing at your phone sees only a small unlabeled dot. Press and hold the dot to trigger.',
  );

  const DangerBarMode({
    required this.id,
    required this.label,
    required this.blurb,
  });

  final String id;
  final String label;
  final String blurb;

  static DangerBarMode fromId(String? id) => DangerBarMode.values.firstWhere(
        (m) => m.id == id,
        orElse: () => DangerBarMode.visible,
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
  static const _dangerBarModeKey = 'kasat.danger_bar_mode.v1';
  static const _onboardedKey = 'kasat.onboarded.v1';
  static const _posterTokenKey = 'kasat.alert_poster.v1';
  static const _deviceRateLimitSecretKey = 'kasat.device_rl_secret.v1';

  static const pinLength = 6;
  static const _hashRounds = 100000;
  static const _legacyHashRounds = 20000;

  static final _random = Random.secure();

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ---------------------------------------------------------------- country

  String? get countryCode => _prefs.getString(_countryKey);

  /// Zero-setup default country ('ET' — Ethiopia) when the survivor has not
  /// explicitly changed her country in Settings.
  String get effectiveCountryCode => countryCode ?? 'ET';

  /// Only an active country is stored. An unlaunched tap never writes.
  Future<void> setCountryCode(String code) async {
    final country = countryByCode(code);
    if (country == null || !country.active) return;
    await _prefs.setString(_countryKey, code);
  }

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
    if (_constantTimeEquals(stored, _hash(pin, salt, _hashRounds))) {
      return true;
    }
    return _constantTimeEquals(stored, _hash(pin, salt, _legacyHashRounds));
  }

  // --------------------------------------------------------------- disguise

  AppDisguise get disguise => AppDisguise.fromId(_prefs.getString(_disguiseKey));

  Future<void> setDisguise(AppDisguise disguise) =>
      _prefs.setString(_disguiseKey, disguise.id);

  // ---------------------------------------------------- danger bar visibility

  DangerBarMode get dangerBarMode =>
      DangerBarMode.fromId(_prefs.getString(_dangerBarModeKey));

  Future<void> setDangerBarMode(DangerBarMode mode) =>
      _prefs.setString(_dangerBarModeKey, mode.id);

  /// Clears the stored PIN hash and salt. Used only when the survivor chooses
  /// to wipe her on-device saved history after forgetting her PIN (her cases
  /// remain accessible via written tracking codes).
  Future<void> clearPin() async {
    await _prefs.remove(_pinHashKey);
    await _prefs.remove(_pinSaltKey);
  }

  // ------------------------------------------------------------- onboarding

  bool get onboardingComplete => (_prefs.getBool(_onboardedKey) ?? false) && countryCode != null;

  /// Opaque handle used only by Community Alerts so a poster can close their
  /// own post. Isolated from reports on purpose.
  String posterToken() {
    final existing = _prefs.getString(_posterTokenKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final token = 'P-${base64Url.encode(List<int>.generate(12, (_) => _random.nextInt(256)))}';
    _prefs.setString(_posterTokenKey, token);
    return token;
  }

  /// High-entropy installation secret held only on this handset. Sent on
  /// emergency dispatch so the server can coalesce repeat panic taps from the
  /// same device without matching on location or IP.
  String deviceSecret() {
    var secret = _prefs.getString(_deviceRateLimitSecretKey);
    if (secret == null || secret.isEmpty) {
      secret = base64Url.encode(
        List<int>.generate(32, (_) => _random.nextInt(256)),
      );
      _prefs.setString(_deviceRateLimitSecretKey, secret);
    }
    return secret;
  }

  /// Legacy one-way fingerprint. Prefer [deviceSecret] for new RPCs.
  String deviceRateLimitHash() {
    return sha256.convert(utf8.encode('kasat-rl-v1|${deviceSecret()}')).toString();
  }

  Future<void> completeOnboarding() => _prefs.setBool(_onboardedKey, true);

  // ------------------------------------------------------------------ crypto

  static String _newSalt() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    return base64Url.encode(bytes);
  }

  /// Iterated SHA-256. A six-digit PIN only has a million possible values, so
  /// the rounds are what make an offline guess against a copied plist cost
  /// something rather than being instant.
  static String _hash(String pin, String salt, [int rounds = _hashRounds]) {
    var digest = sha256.convert(utf8.encode('$salt|$pin')).bytes;
    for (var i = 1; i < rounds; i++) {
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
