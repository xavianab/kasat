import 'package:flutter_test/flutter_test.dart';
import 'package:kasat_mobile/features/accounts/identity_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late IdentityStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = IdentityStore();
    await store.init();
  });

  test('phone is stored encrypted, not as plaintext in prefs', () async {
    await store.save(
      const IdentityRecord(
        displayName: 'Moonkit',
        channel: IdentityChannel.phone,
        handle: '+251911000000',
      ),
    );

    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys()) {
      final value = prefs.get(key);
      if (value is String) {
        expect(value, isNot(contains('+251911000000')), reason: 'leaked via $key');
        expect(value, isNot(contains('Moonkit')), reason: 'display leaked via $key');
      }
    }

    expect(store.read()?.handle, '+251911000000');
    expect(store.displayName, 'Moonkit');
  });
}
