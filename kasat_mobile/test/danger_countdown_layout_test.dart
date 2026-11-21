import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasat_mobile/app.dart';
import 'package:kasat_mobile/features/danger/danger_countdown_sheet.dart';
import 'package:kasat_mobile/theme/kasat_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/test_welcome.dart';

const _narrow = Size(320, 640);
const _largest = TextScaler.linear(2);

Future<void> _pumpDanger(
  WidgetTester tester, {
  required Brightness brightness,
  required String lang,
}) async {
  await tester.binding.setSurfaceSize(_narrow);
  KC.bind(brightness);
  final theme =
      brightness == Brightness.dark ? KasatTheme.dark() : KasatTheme.light();

  final root = await testWelcome(
    home: Theme(
      data: theme,
      child: Builder(
        builder: (context) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              size: _narrow,
              textScaler: _largest,
              platformBrightness: brightness,
              disableAnimations: true,
            ),
            child: Builder(
              builder: (context) {
                return Scaffold(
                  body: Center(
                    child: TextButton(
                      key: const Key('open-danger'),
                      onPressed: () => DangerCountdownSheet.show(context),
                      child: const Text('Open'),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    ),
  );

  await tester.pumpWidget(root);
  await tester.pump();

  final scope = KasatScope.of(tester.element(find.byKey(const Key('open-danger'))));
  await scope.settings.setThemeMode(
    brightness == Brightness.dark ? KasatThemeMode.dark : KasatThemeMode.light,
  );
  await scope.i18n.trySet(lang);
  await tester.pump();

  await tester.tap(find.byKey(const Key('open-danger')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    DangerCountdownSheet.debugResetVisible();
  });

  for (final brightness in [Brightness.light, Brightness.dark]) {
    for (final lang in ['en', 'am']) {
      testWidgets(
        'danger countdown has no overflow at 320px, 2x font, $brightness, $lang',
        (tester) async {
          await _pumpDanger(
            tester,
            brightness: brightness,
            lang: lang,
          );

          expect(tester.takeException(), isNull);
          expect(find.byType(DangerCountdownSheet), findsOneWidget);
          expect(find.byKey(DangerCountdownSheet.cancelButtonKey), findsOneWidget);
          expect(find.byKey(DangerCountdownSheet.silentToggleKey), findsOneWidget);
          expect(find.byKey(DangerCountdownSheet.ringKey), findsOneWidget);

          // Cancel stays reachable at the bottom of the screen.
          final cancel = tester.getRect(
            find.byKey(DangerCountdownSheet.cancelButtonKey),
          );
          expect(cancel.height, greaterThanOrEqualTo(56));
          expect(cancel.bottom, lessThanOrEqualTo(_narrow.height));

          // Scroll the silent card into view before tapping (large fonts).
          await tester.ensureVisible(
            find.byKey(DangerCountdownSheet.silentToggleKey),
          );
          await tester.pump();
          await tester.tap(find.byKey(DangerCountdownSheet.silentToggleKey));
          await tester.pump();
          expect(tester.takeException(), isNull);

          await tester.ensureVisible(
            find.byKey(DangerCountdownSheet.cancelButtonKey),
          );
          await tester.pump();
          await tester.tap(find.byKey(DangerCountdownSheet.cancelButtonKey));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
