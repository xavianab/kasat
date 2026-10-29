import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasat_mobile/data/safety_plan_store.dart';
import 'package:kasat_mobile/features/more/more_menu.dart';
import 'package:kasat_mobile/features/more/safety_plan_view.dart';
import 'package:kasat_mobile/theme/kasat_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/test_welcome.dart';

void main() {
  testWidgets('welcome keeps the four main actions and adds More and Vent', (tester) async {
    await tester.pumpWidget(await testWelcome());

    expect(find.text('Tell us what happened'), findsOneWidget);
    expect(find.text('Check my case'), findsOneWidget);
    expect(find.text('Hotlines & support'), findsOneWidget);
    expect(find.text('Notices'), findsOneWidget);
    expect(find.text('Vent here'), findsOneWidget);
    expect(find.byKey(MoreMenu.buttonKey), findsOneWidget);
  });

  testWidgets('safety plan ticks persist on this phone', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = SafetyPlanStore();
    await store.init();

    await tester.pumpWidget(
      MaterialApp(
        theme: KasatTheme.build(),
        home: SafetyPlanView(store: store),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('safety-place')));
    await tester.pump();
    expect(store.read().checked, contains('place'));
  });
}
