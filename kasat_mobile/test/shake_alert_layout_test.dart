import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasat_mobile/features/duress/shake_alert_intro_sheet.dart';
import 'package:kasat_mobile/features/settings/settings_view.dart';
import 'package:kasat_mobile/theme/kasat_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/test_welcome.dart';

const _narrow = Size(320, 640);
const _largest = TextScaler.linear(2);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shake intro sheet has no overflow at 320px or large text', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(_narrow);
    KC.bind(Brightness.light);

    final root = await testWelcome(
      home: Theme(
        data: KasatTheme.light(),
        child: Builder(
          builder: (context) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                size: _narrow,
                textScaler: _largest,
                platformBrightness: Brightness.light,
              ),
              child: Scaffold(
                body: Center(
                  child: TextButton(
                    key: const Key('open-shake-intro'),
                    onPressed: () => ShakeAlertIntroSheet.show(context),
                    child: const Text('Open'),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.pumpWidget(root);
    await tester.pump();
    await tester.tap(find.byKey(const Key('open-shake-intro')));
    await tester.pumpAndSettle();

    expect(find.byKey(ShakeAlertIntroSheet.sheetKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shake settings row has no overflow at 320px or large text', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(_narrow);
    KC.bind(Brightness.light);

    final root = await testWelcome(home: const SettingsView());
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: _narrow, textScaler: _largest),
        child: root,
      ),
    );
    await tester.pump();

    final list = find.descendant(
      of: find.byType(SettingsView),
      matching: find.byType(ListView),
    );
    expect(list, findsOneWidget);

    for (var i = 0; i < 24; i++) {
      if (find
          .text('Shake phone to alert')
          .evaluate()
          .isNotEmpty) {
        break;
      }
      await tester.drag(list, const Offset(0, -280));
      await tester.pump();
    }

    expect(find.text('Shake phone to alert'), findsWidgets);
    expect(find.byKey(SettingsView.shakeToAlertSwitchKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
