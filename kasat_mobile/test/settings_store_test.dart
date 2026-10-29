import 'package:flutter_test/flutter_test.dart';
import 'package:kasat_mobile/data/settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SettingsStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = SettingsStore();
    await store.init();
  });

  group('PIN', () {
    test('starts unset', () {
      expect(store.hasPin, isFalse);
      expect(store.verifyPin('482913'), isFalse);
    });

    test('verifies the right code and rejects the rest', () async {
      await store.setPin('482913');

      expect(store.hasPin, isTrue);
      expect(store.verifyPin('482913'), isTrue);
      expect(store.verifyPin('482914'), isFalse);
      expect(store.verifyPin(''), isFalse);
      expect(store.verifyPin('48291'), isFalse);
    });

    test('never stores the PIN itself', () async {
      await store.setPin('482913');
      final prefs = await SharedPreferences.getInstance();

      // A seized handset yields this plist. It must not contain the code.
      for (final key in prefs.getKeys()) {
        final value = prefs.get(key);
        if (value is String) {
          expect(value, isNot(contains('482913')), reason: 'leaked via $key');
        }
      }
    });

    test('salts per PIN, so the same code hashes differently', () async {
      await store.setPin('482913');
      final prefs = await SharedPreferences.getInstance();
      final first = prefs.getString('kasat.pin_hash.v1');

      await store.setPin('482913');
      final second = prefs.getString('kasat.pin_hash.v1');

      expect(first, isNotNull);
      expect(second, isNot(first));
      expect(store.verifyPin('482913'), isTrue);
    });

    test('a changed PIN invalidates the old one', () async {
      await store.setPin('482913');
      await store.setPin('112233');

      expect(store.verifyPin('482913'), isFalse);
      expect(store.verifyPin('112233'), isTrue);
    });
  });

  group('country', () {
    test('is unset until onboarding stores it', () async {
      expect(store.countryCode, isNull);

      await store.setCountryCode('ET');
      expect(store.countryCode, 'ET');

      await store.setCountryCode('US');
      expect(store.countryCode, 'US');
    });

    test('refuses to store an unlaunched country', () async {
      await store.setCountryCode('ET');
      await store.setCountryCode('KE');
      expect(store.countryCode, 'ET');
    });
  });

  group('onboarding', () {
    test('is incomplete without a country, even if flagged done', () async {
      // Guards against a half-finished setup leaving the app with no country
      // to route reports or help lines against.
      await store.completeOnboarding();
      expect(store.onboardingComplete, isFalse);

      await store.setCountryCode('ET');
      expect(store.onboardingComplete, isTrue);
    });
  });

  group('disguise', () {
    test('defaults to the real identity', () {
      expect(store.disguise, AppDisguise.none);
      expect(store.disguise.iconName, isNull);
    });

    test('round-trips a choice and maps it to an asset name', () async {
      await store.setDisguise(AppDisguise.notes);

      expect(store.disguise, AppDisguise.notes);
      expect(store.disguise.iconName, 'AltIconNotes');
    });

    test('falls back to the real identity on an unknown stored value', () async {
      SharedPreferences.setMockInitialValues({'kasat.disguise.v1': 'GONE'});
      final fresh = SettingsStore();
      await fresh.init();

      expect(fresh.disguise, AppDisguise.none);
    });
  });

  group('biometrics', () {
    test('is off unless chosen', () async {
      expect(store.biometricEnabled, isFalse);

      await store.setBiometricEnabled(true);
      expect(store.biometricEnabled, isTrue);
    });
  });
}
