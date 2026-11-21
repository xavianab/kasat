import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasat_mobile/app.dart';
import 'package:kasat_mobile/features/report/report_form_view.dart';
import 'package:kasat_mobile/features/shell/shell_view.dart';
import 'package:kasat_mobile/theme/kasat_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/test_welcome.dart';

const _phone = Size(360, 640);
const _largest = TextScaler.linear(2);

Future<KasatScope> _pumpKasat(
  WidgetTester tester, {
  required Widget child,
}) async {
  await tester.binding.setSurfaceSize(_phone);
  KC.bindPalette(KasatPalette.kasat);

  final root = await testWelcome(
    home: Theme(
      data: KasatTheme.kasat(),
      child: Builder(
        builder: (context) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              size: _phone,
              textScaler: _largest,
              platformBrightness: Brightness.light,
            ),
            child: child,
          );
        },
      ),
    ),
  );

  await tester.pumpWidget(root);
  await tester.pump();

  final scope = KasatScope.of(tester.element(find.byWidget(child)));
  await scope.settings.setThemeMode(KasatThemeMode.kasat);
  KC.bindMode(KasatThemeMode.kasat, Brightness.light);
  scope.unlockPinSession();
  await tester.pump();
  return scope;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('home has no overflow in Kasat theme at 360px and 2x font',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpKasat(
      tester,
      child: const ShellView(initialTab: ShellTab.home),
    );

    expect(tester.takeException(), isNull);
    expect(KC.palette, KasatPalette.kasat);
    expect(KC.canvas, const Color(0xFFFFFAF8));
    expect(KC.primary, const Color(0xFFC4587C));
    expect(KC.button, const Color(0xFF3D2A2A));
    expect(KC.urgent, const Color(0xFFC9372C));
    expect(find.text('Kasat'), findsWidgets);
    expect(find.text('Report what happened'), findsOneWidget);
    expect(find.text('Safety tips'), findsOneWidget);
  });

  testWidgets('report has no overflow in Kasat theme at 360px and 2x font',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpKasat(
      tester,
      child: const ShellView(initialTab: ShellTab.report),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(ReportFormView), findsOneWidget);

    final scrollables = find.byType(Scrollable);
    if (scrollables.evaluate().isNotEmpty) {
      for (var i = 0; i < 6; i++) {
        await tester.drag(scrollables.first, const Offset(0, -220));
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
    }
  });
}
