import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasat_mobile/features/onboarding/country_picker.dart';
import 'package:kasat_mobile/theme/kasat_theme.dart';

void main() {
  Widget host(Widget child) {
    return MaterialApp(
      theme: KasatTheme.build(),
      home: Scaffold(body: ListView(children: [child])),
    );
  }

  testWidgets('lists flags and keeps live countries at the top', (tester) async {
    await tester.pumpWidget(
      host(CountryPicker(selectedCode: null, onSelect: (_) {})),
    );

    expect(find.text('Ethiopia'), findsOneWidget);
    expect(find.text('United States'), findsOneWidget);
    expect(find.text('Afghanistan'), findsOneWidget);
  });

  testWidgets('search filters the list live', (tester) async {
    await tester.pumpWidget(
      host(CountryPicker(selectedCode: null, onSelect: (_) {})),
    );

    await tester.enterText(find.byType(TextField), 'ken');
    await tester.pump();

    expect(find.text('Kenya'), findsOneWidget);
    expect(find.text('Ethiopia'), findsNothing);
  });

  testWidgets('an active country can be selected', (tester) async {
    String? selected;
    await tester.pumpWidget(
      host(CountryPicker(selectedCode: selected, onSelect: (c) => selected = c)),
    );

    await tester.tap(find.text('Ethiopia'));
    await tester.pump();
    expect(selected, 'ET');
  });

  testWidgets('an unlaunched country shows a calm notice, not an error', (tester) async {
    String? selected;
    await tester.pumpWidget(
      host(CountryPicker(selectedCode: null, onSelect: (c) => selected = c)),
    );

    await tester.enterText(find.byType(TextField), 'Kenya');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('country-KE')));
    await tester.pumpAndSettle();

    expect(selected, isNull);
    expect(
      find.text('Kasat isn’t in your country yet. We’re working on it.'),
      findsOneWidget,
    );
    expect(find.text('OK'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsNothing);
    expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
  });
}
