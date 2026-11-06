import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasat_mobile/data/safety_plan_store.dart';
import 'package:kasat_mobile/features/more/more_menu.dart';
import 'package:kasat_mobile/features/more/safety_plan_view.dart';
import 'package:kasat_mobile/theme/kasat_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/test_welcome.dart';

void main() {
  testWidgets('home shows the three action buttons, safety tips, and More', (tester) async {
    await tester.pumpWidget(await testWelcome());
    await tester.pump();

    expect(find.text('Report what happened'), findsOneWidget);
    expect(find.text('Check my case'), findsOneWidget);
    expect(find.text('Get help now'), findsOneWidget);
    expect(find.text('Safety tips'), findsOneWidget);
    expect(
      find.text('Free. Anonymous. You decide who sees your report.'),
      findsOneWidget,
    );
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
