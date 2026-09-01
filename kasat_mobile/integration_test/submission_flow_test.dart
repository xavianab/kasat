import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:kasat_mobile/app.dart';
import 'package:kasat_mobile/core/tracking_id.dart';
import 'package:kasat_mobile/data/attachment_store.dart';
import 'package:kasat_mobile/data/local_incident_repository.dart';

/// Walks the survivor path on a real simulator: welcome → classify → describe
/// → locate → transmit → receipt → live tracking → resources.
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

  /// Drags the intake list until [target] has been built and laid out.
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

  testWidgets('anonymous report reaches a trackable case', (tester) async {
    final repository = LocalIncidentRepository();
    await repository.init();

    await tester.pumpWidget(
      KasatApp(repository: repository, attachments: AttachmentStore()),
    );
    await advance(tester);

    expect(find.text('SPEAK\nWITHOUT FEAR.'), findsOneWidget);
    await shoot(tester, '01-welcome');

    await tester.tap(find.text('FILE ANONYMOUS REPORT'));
    await advance(tester);
    expect(find.text('Anonymous intake'), findsOneWidget);
    await shoot(tester, '02-intake');

    // 01 — classification.
    await tester.tap(find.text('Select incident type'));
    await advance(tester);
    await shoot(tester, '03-classification');
    await tester.tap(find.text('Physical Assault'));
    await advance(tester);

    // The submit bar must still refuse: the description is empty.
    expect(
      find.text('DESCRIPTION NEEDS 40+ CHARACTERS'),
      findsOneWidget,
      reason: 'classification alone should not unlock transmit',
    );

    // 02 — statement.
    await tester.enterText(
      find.byType(TextField).first,
      'Two men blocked the service entrance behind the market at closing time '
      'and assaulted a vendor who refused to hand over the day takings. Three '
      'other traders saw it happen.',
    );
    await advance(tester);

    // 04 — approximate location.
    await scrollTo(tester, find.text('REPORTED PRECISION'));
    await tester.enterText(fieldWithHint('-6.7924'), '-6.792354');
    await advance(tester, ms: 300);
    await tester.enterText(fieldWithHint('39.2083'), '39.208328');
    await advance(tester);

    // The coordinate must be degraded before it is ever attached.
    expect(find.text('6.792°S 39.208°E'), findsNothing);
    await shoot(tester, '04-payload-ready');

    expect(find.text('PAYLOAD READY · IDENTIFIER MINTED ON SEND'), findsOneWidget);

    await tester.tap(find.text('TRANSMIT REPORT'));
    await tester.pump(const Duration(milliseconds: 400));
    await shoot(tester, '05-transmitting');

    await waitFor(tester, find.text('REPORT ACCEPTED'), ms: 8000);
    expect(find.text('REPORT ACCEPTED'), findsOneWidget);
    expect(find.text('WRITE THIS CODE DOWN'), findsOneWidget);
    await shoot(tester, '06-receipt');

    // The receipt must show a well-formed, on-device-minted identifier.
    final ids = await repository.localTrackingIds();
    expect(ids, isNotEmpty);
    final trackingId = ids.first;
    expect(TrackingId.isValid(trackingId), isTrue, reason: 'malformed: $trackingId');
    expect(find.text(trackingId), findsOneWidget);

    await tester.tap(find.text('TRACK THIS CASE'));
    await waitFor(tester, find.text('AUDIT TRAIL'), ms: 6000);
    expect(find.text('UNASSIGNED'), findsOneWidget);
    await shoot(tester, '07-tracking');

    // Realtime: the demo dispatcher claims the case ~20s after submission and
    // the already-open lookup view must move without any user interaction.
    //
    // Asserted against the note the dispatcher writes, not the status label:
    // StatusTrack always renders all three step names, so matching on
    // "UNDER INVESTIGATION" would pass against a greyed-out placeholder.
    const claimNote = 'Case claimed by duty officer. Evidence review opened.';
    await waitFor(tester, find.text(claimNote), ms: 40000);
    expect(
      find.text(claimNote),
      findsOneWidget,
      reason: 'live status did not propagate to an open tracking view',
    );
    expect(find.text('STN-04'), findsOneWidget);
    expect((await repository.lookup(trackingId))?.status.code, 'UNDER_INVESTIGATION');
    await shoot(tester, '08-tracking-live');

    await tester.tap(find.text('HELP'));
    await advance(tester);
    expect(find.text('Support directory'), findsOneWidget);
    await shoot(tester, '09-resources');
  });
}
