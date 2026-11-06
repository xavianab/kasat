import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasat_mobile/app.dart';
import 'package:kasat_mobile/core/network_status.dart';
import 'package:kasat_mobile/data/attachment_store.dart';
import 'package:kasat_mobile/data/local_alert_repository.dart';
import 'package:kasat_mobile/data/local_incident_repository.dart';
import 'package:kasat_mobile/data/settings_store.dart';
import 'package:kasat_mobile/features/accounts/identity_store.dart';
import 'package:kasat_mobile/features/duress/duress_store.dart';
import 'package:kasat_mobile/features/lookup/lookup_view.dart';
import 'package:kasat_mobile/features/report/report_form_view.dart';
import 'package:kasat_mobile/features/report/widgets/location_picker.dart';
import 'package:kasat_mobile/features/settings/settings_view.dart';
import 'package:kasat_mobile/features/shell/shell_view.dart';
import 'package:kasat_mobile/features/welcome/first_launch_intro.dart';
import 'package:kasat_mobile/i18n/i18n.dart';
import 'package:kasat_mobile/theme/kasat_theme.dart';
import 'package:kasat_mobile/widgets/k_field.dart';
import 'package:kasat_mobile/widgets/kasat_button.dart';
import 'package:kasat_mobile/widgets/panel.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/test_welcome.dart';

const _phoneSize = Size(360, 640);
const _largest = TextScaler.linear(2);
const _keyboardOpen = EdgeInsets.only(bottom: 260);

Future<void> _pumpScreen(
  WidgetTester tester, {
  required Brightness brightness,
  required Widget child,
}) async {
  await tester.binding.setSurfaceSize(_phoneSize);
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
              size: _phoneSize,
              textScaler: _largest,
              viewInsets: _keyboardOpen,
              platformBrightness: brightness,
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
  await scope.settings.setThemeMode(
    brightness == Brightness.dark ? KasatThemeMode.dark : KasatThemeMode.light,
  );
  scope.unlockPinSession();
  await scope.i18n.trySet('am');
  await tester.pump();
}

Future<void> _scrollUntilFound(
  WidgetTester tester,
  Finder scrollable,
  Finder target,
) async {
  for (var i = 0; i < 12 && target.evaluate().isEmpty; i++) {
    await tester.drag(scrollable, const Offset(0, -240));
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.takeException(), isNull);
  }
  expect(target, findsWidgets);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('first-launch intro shows 3 cards once only and skips on danger shortcut', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsStore();
    await settings.init();
    final repository = LocalIncidentRepository();
    await repository.init();
    final alerts = LocalAlertRepository();
    await alerts.init();
    final identity = IdentityStore();
    await identity.init();
    final duress = DuressStore();
    await duress.init();
    final i18n = I18n();
    await i18n.init();

    await tester.pumpWidget(
      KasatApp(
        repository: repository,
        attachments: AttachmentStore(),
        settings: settings,
        alerts: alerts,
        identity: identity,
        duress: duress,
        i18n: i18n,
        network: NetworkStatus(fakeOnline: true),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FirstLaunchIntro), findsOneWidget);
    expect(find.text('You stay anonymous'), findsOneWidget);
    expect(find.byKey(FirstLaunchIntro.skipButtonKey), findsOneWidget);

    await tester.tap(find.byKey(FirstLaunchIntro.nextButtonKey));
    await tester.pumpAndSettle();
    expect(find.text('You choose who sees it'), findsOneWidget);

    await tester.tap(find.byKey(FirstLaunchIntro.nextButtonKey));
    await tester.pumpAndSettle();
    expect(find.text('Someone answers'), findsOneWidget);

    await tester.tap(find.byKey(FirstLaunchIntro.nextButtonKey));
    await tester.pumpAndSettle();
    expect(find.byType(FirstLaunchIntro), findsNothing);
    expect(settings.introSeen, isTrue);

    // Relaunching never shows the intro again.
    await tester.pumpWidget(
      KasatApp(
        repository: repository,
        attachments: AttachmentStore(),
        settings: settings,
        alerts: alerts,
        identity: identity,
        duress: duress,
        i18n: i18n,
        network: NetworkStatus(fakeOnline: true),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(FirstLaunchIntro), findsNothing);

    // Danger shortcut launch skips the intro even on a fresh install.
    SharedPreferences.setMockInitialValues({});
    final freshSettings = SettingsStore();
    await freshSettings.init();
    const channel = MethodChannel('app.kasat/privacy');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'launchIsDanger') return true;
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    await tester.pumpWidget(
      KasatApp(
        repository: repository,
        attachments: AttachmentStore(),
        settings: freshSettings,
        alerts: alerts,
        identity: identity,
        duress: duress,
        i18n: i18n,
        network: NetworkStatus(fakeOnline: true),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(FirstLaunchIntro), findsNothing);
  });

  testWidgets('field labels wrap in Amharic at the largest font size', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: _largest),
        child: const MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: EdgeInsets.all(16),
              child: KFieldLabel(
                'Nearest landmark (አቅራቢያ የሚገኝ ምልክት)',
                optional: true,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('አቅራቢያ'), findsOneWidget);
    expect(tester.getSize(find.byType(KFieldLabel)).width, lessThanOrEqualTo(320));
  });

  testWidgets('location section says optional once and uses short labels', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final landmark = TextEditingController();
    addTearDown(landmark.dispose);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: _largest),
        child: MaterialApp(
          home: Scaffold(
            body: LocationPicker(
              selectedSubCity: null,
              onSubCityChanged: (_) {},
              landmarkController: landmark,
              resolved: null,
              onChanged: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('optional'), findsNothing);
    expect(find.text('Optional'), findsNothing);
    expect(find.textContaining('(optional)'), findsNothing);
    expect(find.text('No location attached'), findsOneWidget);
    expect(find.text('Near a church, school or shop'), findsOneWidget);

    await tester.tap(find.byKey(LocationPicker.subCityDropdownKey));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Skip'), findsWidgets);
    expect(find.text('Prefer not to say / Skip sub-city'), findsNothing);
  });

  for (final brightness in Brightness.values) {
    final modeName = brightness == Brightness.dark ? 'dark' : 'light';

    testWidgets(
      'Home screen has no overflow ($modeName, 360x640, keyboard open, 2x font, Amharic)',
      (tester) async {
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await _pumpScreen(
          tester,
          brightness: brightness,
          child: const ShellView(initialTab: ShellTab.home),
        );

        expect(tester.takeException(), isNull);
        expect(find.text('Hotlines'), findsNothing);
      },
    );

    testWidgets(
      'Report screen has no overflow ($modeName, 360x640, keyboard open, 2x font, Amharic)',
      (tester) async {
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await _pumpScreen(
          tester,
          brightness: brightness,
          child: const ShellView(initialTab: ShellTab.report),
        );

        expect(tester.takeException(), isNull);
        // Bottom tab bar is hidden while the keyboard is open.
        expect(find.text('Hotlines'), findsNothing);

        final reportFinder = find.byType(ReportFormView);
        expect(
          find.descendant(of: reportFinder, matching: find.byType(KPanel)),
          findsNothing,
        );

        final list = find.descendant(
          of: reportFinder,
          matching: find.byType(ListView),
        );

        await _scrollUntilFound(
          tester,
          list,
          find.textContaining('አቅራቢያ'),
        );
        expect(find.text('Optional. You can skip both.'), findsOneWidget);

        await _scrollUntilFound(
          tester,
          list,
          find.text('Save for later'),
        );
        expect(find.text('Send report'), findsOneWidget);
        expect(find.text('Send urgent'), findsOneWidget);
        expect(
          find.text('Choose what kind of thing happened to continue'),
          findsOneWidget,
        );

        final send = tester.widget<KButton>(
          find.widgetWithText(KButton, 'Send report'),
        );
        final urgent = tester.widget<KButton>(
          find.widgetWithText(KButton, 'Send urgent'),
        );
        expect(send.onPressed, isNull);
        expect(urgent.onPressed, isNull);
        expect(urgent.kind, KButtonKind.danger);
        expect(send.kind, KButtonKind.primary);
      },
    );

    testWidgets(
      'My case screen has no overflow ($modeName, 360x640, keyboard open, 2x font, Amharic)',
      (tester) async {
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await _pumpScreen(
          tester,
          brightness: brightness,
          child: const ShellView(initialTab: ShellTab.track),
        );

        expect(tester.takeException(), isNull);
        expect(find.text('Hotlines'), findsNothing);

        final lookupState = tester.state<LookupViewState>(
          find.byType(LookupView),
        );
        unawaited(lookupState.loadTrackingId('KST-4RT7Q'));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);

        // Fixed reply bar is visible at the bottom of the screen.
        expect(find.text('Send'), findsOneWidget);

        final list = find.descendant(
          of: find.byType(LookupView),
          matching: find.byType(ListView),
        );
        for (var i = 0; i < 6; i++) {
          await tester.drag(list, const Offset(0, -240));
          await tester.pump(const Duration(milliseconds: 50));
          expect(tester.takeException(), isNull);
        }
      },
    );

    testWidgets(
      'Settings screen has no overflow ($modeName, 360x640, keyboard open, 2x font, Amharic)',
      (tester) async {
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await _pumpScreen(
          tester,
          brightness: brightness,
          child: const SettingsView(),
        );

        expect(tester.takeException(), isNull);
        expect(find.text('Appearance'), findsOneWidget);
        expect(find.text('Match phone'), findsWidgets);
        expect(find.text('Light'), findsWidgets);
        expect(find.text('Dark'), findsWidgets);

        final list = find.descendant(
          of: find.byType(SettingsView),
          matching: find.byType(ListView),
        );
        for (var i = 0; i < 8; i++) {
          await tester.drag(list, const Offset(0, -240));
          await tester.pump();
          expect(tester.takeException(), isNull);
        }
      },
    );
  }
}
