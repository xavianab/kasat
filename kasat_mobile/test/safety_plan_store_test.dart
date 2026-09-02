import 'package:flutter_test/flutter_test.dart';
import 'package:kasat_mobile/data/safety_plan_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SafetyPlanStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = SafetyPlanStore();
    await store.init();
  });

  test('starts empty', () {
    expect(store.read().isEmpty, isTrue);
  });

  test('ticks persist and can be cleared', () async {
    await store.toggle('place');
    await store.toggle('person');
    expect(store.read().checked, {'place', 'person'});

    await store.toggle('place');
    expect(store.read().checked, {'person'});

    await store.clear();
    expect(store.read().isEmpty, isTrue);
  });

  test(
    'words stay on the device store and never mix with a report key',
    () async {
      await store.save(
        const SafetyPlan(safePlace: 'aunt', trustedPerson: 'Meron'),
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('kasat.safety_plan.place.v1'), 'aunt');
      expect(
        prefs.getKeys().any((k) => k.startsWith('kasat.incidents')),
        isFalse,
      );
      expect(store.read().safePlace, 'aunt');
      expect(store.read().trustedPerson, 'Meron');
    },
  );
}
