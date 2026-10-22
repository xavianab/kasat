import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kasat_mobile/app.dart';
import 'package:kasat_mobile/core/tracking_id.dart';
import 'package:kasat_mobile/core/network_status.dart';
import 'package:kasat_mobile/data/attachment_store.dart';
import 'package:kasat_mobile/data/local_alert_repository.dart';
import 'package:kasat_mobile/data/local_incident_repository.dart';
import 'package:kasat_mobile/data/settings_store.dart';
import 'package:kasat_mobile/features/accounts/identity_store.dart';
import 'package:kasat_mobile/features/duress/duress_store.dart';
import 'package:kasat_mobile/features/vent/local_vent_repository.dart';
import 'package:kasat_mobile/i18n/i18n.dart';

/// Walks the survivor path on a real simulator: first-launch setup (country,
/// PIN, disguise) → welcome → describe → locate → send → receipt → live
/// tracking → country help lines.
///
/// Screenshots are captured at each step and land in `screenshots/`.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// Kasat has permanently-repeating animations (the live status dots), so
  /// `pumpAndSettle` would never return. Pump a fixed window instead.
  Future<void> advance(WidgetTester tester, {int ms = 900}) async {
    for (var i = 0; i < ms ~/ 40; i++) {
      await tester.pump(const Duration(milliseconds: 40));
    }
  }

  /// Drags the nearest list until [target] has been built and laid out.
  Future<void> scrollTo(WidgetTester tester, Finder target) async {
    for (var i = 0; i < 14 && !tester.any(target); i++) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -240));
      await advance(tester, ms: 240);
    }
    expect(target, findsWidgets, reason: 'never scrolled into view');
  }

  /// Bounded by a real stopwatch rather than a pump count, because the demo
  /// dispatcher runs on a wall-clock timer.
  Future<void> waitFor(WidgetTester tester, Finder target, {int ms = 25000}) async {
    final clock = Stopwatch()..start();
    while (clock.elapsedMilliseconds < ms && !tester.any(target)) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Screenshots are pulled from the last rendered engine frame, which can
  /// trail the widget tree by a frame or two. Pump before capturing so the
  /// image matches the assertion that preceded it.
  Future<void> shoot(WidgetTester tester, String name) async {
    await advance(tester, ms: 400);
    await binding.takeScreenshot(name);
  }

  /// The text field behind a placeholder, located by the placeholder itself.
  Finder fieldWithHint(String hint) =>
      find.ancestor(of: find.text(hint), matching: find.byType(TextField));

  Future<void> tapText(WidgetTester tester, String label, {int ms = 900}) async {
    await tester.tap(find.text(label));
    await advance(tester, ms: ms);
  }

  /// Six taps on the in-app keypad.
  Future<void> enterPin(WidgetTester tester, String pin) async {
    for (final digit in pin.split('')) {
      await tester.tap(find.text(digit));
      await advance(tester, ms: 120);
    }
    await advance(tester, ms: 300);
  }

  const pin = '482913';

  testWidgets('setup, anonymous report, live tracking, and help lines',
      (tester) async {
    // A previous run leaves onboarding marked complete, which would skip the
    // setup flow this test is asserting on.
    await (await SharedPreferences.getInstance()).clear();

    final repository = LocalIncidentRepository();
    await repository.init();
    final settings = SettingsStore();
    await settings.init();

    final alerts = LocalAlertRepository();
    await alerts.init();
    final vents = LocalVentRepository();
    await vents.init();
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
        vents: vents,
        identity: identity,
        duress: duress,
        i18n: i18n,
        network: NetworkStatus(),
      ),
    );
    await advance(tester);

    // ------------------------------------------------ first launch: country

    expect(find.text('Where are you?'), findsOneWidget);
    expect(
      find.text('Soon'),
      findsWidgets,
      reason: 'picker should mark unlaunched countries without blocking the list',
    );
    await shoot(tester, '01-country');

    await tapText(tester, 'Ethiopia');
    await tapText(tester, 'Continue');

    // --------------------------------------------------- first launch: PIN

    expect(find.text('Choose a code'), findsOneWidget);
    await shoot(tester, '02-choose-code');
    await enterPin(tester, pin);

    expect(find.text('Once more'), findsOneWidget);
    await enterPin(tester, pin);

    // ------------------------------------------- first launch: Face ID, icon

    expect(find.text('Faster way in'), findsOneWidget);
    await tapText(tester, 'Continue');

    expect(find.text('How it looks on your phone'), findsOneWidget);
    await shoot(tester, '03-disguise');
    // Left on the real icon: choosing an alternate fires a system alert that
    // would block the test.
    await tapText(tester, 'Finish setup');

    expect(settings.countryCode, 'ET');
    expect(settings.hasPin, isTrue);
    expect(settings.verifyPin(pin), isTrue);
    expect(settings.verifyPin('000000'), isFalse);

    // ------------------------------------------------------------- welcome

    expect(find.text('Speak\nwithout fear.'), findsOneWidget);
    expect(
      find.text('Ethiopia'),
      findsOneWidget,
      reason: 'selected country should be visible on the welcome screen',
    );
    await shoot(tester, '04-welcome');

    await tapText(tester, 'Tell us what happened');

    // ------------------------------------------------------------- intake

    await tapText(tester, 'Choose one');
    await shoot(tester, '05-categories');
    await tapText(tester, 'Physical assault');

    expect(
      find.text('A little more detail — at least 40 characters'),
      findsOneWidget,
      reason: 'choosing a category alone should not enable sending',
    );

    // Contains a phrase the on-device crisis check looks for.
    await tester.enterText(
      find.byType(TextField).first,
      'Two men blocked the service entrance behind the market at closing time '
      'and attacked a vendor who would not hand over the day takings. One of '
      'them is still outside.',
    );
    await advance(tester);

    // Crisis lines must come from the selected country's table.
    expect(find.text('Do you need help right now?'), findsOneWidget);
    expect(find.text('Ethiopian Federal Police'), findsOneWidget);
    await shoot(tester, '06-crisis-banner');

    await scrollTo(tester, find.text('How vague should this be?'));
    await tester.enterText(fieldWithHint('9.0108'), '9.010812');
    await advance(tester, ms: 300);
    await tester.enterText(fieldWithHint('38.7613'), '38.761334');
    await advance(tester);

    // The coordinate must be degraded before it is ever attached: at district
    // precision the label carries two decimals, and the typed fix is gone.
    expect(find.text('9.011°N 38.761°E'), findsNothing);
    expect(find.textContaining('°N'), findsWidgets);
    await shoot(tester, '07-location');

    expect(
      find.text('Ready. Your private code is created when you save.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Save report'));
    await tester.pump(const Duration(milliseconds: 400));
    await shoot(tester, '08-sending');

    // ------------------------------------------------------------- receipt

    await waitFor(tester, find.text('Saved as a draft'), ms: 8000);
    expect(find.text('Saved as a draft'), findsOneWidget);
    await tester.tap(find.text('Send to police'));
    await tester.pump(const Duration(milliseconds: 400));
    await waitFor(tester, find.text('It has been sent'), ms: 8000);
    expect(find.text('It has been sent'), findsOneWidget);
    expect(find.text('Please write this code down'), findsOneWidget);
    await shoot(tester, '09-receipt');

    final ids = await repository.localTrackingIds();
    expect(ids, isNotEmpty);
    final trackingId = ids.first;
    expect(TrackingId.isValid(trackingId), isTrue, reason: 'malformed: $trackingId');
    expect(find.text(trackingId), findsOneWidget);

    // The country selected at onboarding must ride along on the report.
    expect((await repository.lookup(trackingId))?.countryCode, 'ET');

    await tapText(tester, 'Follow my case');
    await waitFor(tester, find.text('What has happened so far'), ms: 6000);
    expect(find.text('Not yet assigned'), findsOneWidget);
    await shoot(tester, '10-tracking');

    expect((await repository.lookup(trackingId))?.status.code, 'sent');
    await shoot(tester, '11-tracking-live');

    // ------------------------------------------------------------ help lines

    await tapText(tester, 'Hotlines');
    expect(find.text('Ministry of Women and Social Affairs hotline'), findsWidgets);
    expect(
      find.text('Not confirmed yet'),
      findsWidgets,
      reason: 'placeholder numbers must be labelled as unverified',
    );
    await shoot(tester, '12-help');
  });
}
