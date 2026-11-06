import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasat_mobile/core/kasat_config.dart';
import 'package:kasat_mobile/data/safety_plan_store.dart';
import 'package:kasat_mobile/features/more/more_menu.dart';
import 'package:kasat_mobile/features/more/safety_plan_view.dart';
import 'package:kasat_mobile/features/welcome/welcome_view.dart';
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
    // Test banner is never shown when KASAT_TEST_BUILD is false.
    expect(find.byKey(HomeTabContent.testBannerKey), findsNothing);
    expect(find.text("Test version. Don't report real incidents."), findsNothing);
  });

  testWidgets('test build shows Home banner and Send feedback mailto in More menu', (tester) async {
    await tester.pumpWidget(
      await testWelcome(
        home: Scaffold(
          body: HomeTabContent(
            offline: false,
            testBuild: true,
            onSelectTab: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(HomeTabContent.testBannerKey), findsOneWidget);
    expect(
      find.text("Test version. Don't report real incidents."),
      findsOneWidget,
    );

    // Non-test build hides Send feedback in the More menu.
    await tester.pumpWidget(
      await testWelcome(
        home: const Scaffold(body: MoreMenuSheet(testBuild: false)),
      ),
    );
    await tester.pump();
    expect(find.byKey(MoreMenu.sendFeedbackKey), findsNothing);

    // Test build shows Send feedback and builds the mailto URI with version only.
    Uri? launched;
    await tester.pumpWidget(
      await testWelcome(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => MoreMenuSheet(
                  testBuild: true,
                  onLaunchUri: (uri) async => launched = uri,
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final feedbackFinder = find.byKey(MoreMenu.sendFeedbackKey);
    await tester.ensureVisible(feedbackFinder);
    await tester.pump();
    expect(feedbackFinder, findsOneWidget);
    expect(find.text('Send feedback'), findsOneWidget);

    await tester.tap(feedbackFinder);
    await tester.pumpAndSettle();

    expect(launched, isNotNull);
    expect(launched!.scheme, 'mailto');
    expect(launched!.path, 'hello@kasatapp.com');
    expect(launched!.queryParameters['subject'], 'Kasat test feedback');
    expect(
      launched!.queryParameters['body'],
      contains('Kasat version: ${KasatConfig.appVersion}'),
    );
    expect(launched!.queryParameters['body'], isNot(contains('KST-')));
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
