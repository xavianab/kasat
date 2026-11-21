import 'package:flutter_test/flutter_test.dart';
import 'package:kasat_mobile/app.dart';
import 'package:kasat_mobile/core/kasat_config.dart';
import 'package:kasat_mobile/core/network_status.dart';
import 'package:kasat_mobile/data/attachment_store.dart';
import 'package:kasat_mobile/data/local_alert_repository.dart';
import 'package:kasat_mobile/data/local_incident_repository.dart';
import 'package:kasat_mobile/data/settings_store.dart';
import 'package:kasat_mobile/features/accounts/identity_store.dart';
import 'package:kasat_mobile/features/danger/danger_controller.dart';
import 'package:kasat_mobile/features/danger/danger_countdown_sheet.dart';
import 'package:kasat_mobile/features/duress/duress_store.dart';
import 'package:kasat_mobile/features/safety/persistent_safety_bar.dart';
import 'package:kasat_mobile/i18n/i18n.dart';
import 'package:kasat_mobile/models/incident.dart';
import 'package:kasat_mobile/models/incident_category.dart';
import 'package:kasat_mobile/models/incident_priority.dart';
import 'package:kasat_mobile/models/incident_status.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _QueuedDangerController extends DangerController {
  _QueuedDangerController({
    required super.repository,
    required super.settings,
    required super.network,
  });

  int escalateCalls = 0;
  bool lastSilent = false;
  int dialerCalls = 0;

  @override
  Future<Incident> escalateNow({bool silent = false}) async {
    escalateCalls++;
    lastSilent = silent;
    if (!silent) {
      dialerCalls++;
    }
    final now = DateTime.now();
    return Incident(
      trackingId: 'KST-QUEUE',
      category: IncidentCategory.other,
      description: 'queued emergency test',
      priority: IncidentPriority.critical,
      status: IncidentStatus.queued,
      countryCode: 'ET',
      submittedAt: now,
      updatedAt: now,
      isEmergency: true,
      silentMode: silent,
      history: const [],
    );
  }

  @override
  Future<void> openEmergencyDialer() async {
    dialerCalls++;
  }
}

Future<_QueuedDangerController> _pumpApp(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final settings = SettingsStore();
  await settings.init();
  await settings.markIntroSeen();
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
  final network = NetworkStatus(fakeOnline: true);
  final danger = _QueuedDangerController(
    repository: repository,
    settings: settings,
    network: network,
  );

  await tester.pumpWidget(
    KasatApp(
      repository: repository,
      attachments: AttachmentStore(),
      settings: settings,
      alerts: alerts,
      identity: identity,
      duress: duress,
      i18n: i18n,
      network: network,
      danger: danger,
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
  return danger;
}

void main() {
  testWidgets('normal mode shows queued fallback and does not auto-close', (tester) async {
    final danger = await _pumpApp(tester);
    await tester.tap(find.byKey(PersistentSafetyBar.dangerButtonKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('EMERGENCY ESCALATION'), findsOneWidget);

    await tester.pump(KasatConfig.dangerCountdown);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(danger.escalateCalls, 1);
    expect(danger.lastSilent, isFalse);
    expect(find.byKey(DangerCountdownSheet.queuedMessageKey), findsOneWidget);
    expect(
      find.textContaining('The phone dialer was opened'),
      findsOneWidget,
    );
    expect(find.byKey(DangerCountdownSheet.queuedCallKey), findsNothing);
    expect(find.byKey(DangerCountdownSheet.queuedDoneKey), findsOneWidget);
  });

  testWidgets('silent mode shows queued fallback with optional call button', (tester) async {
    final danger = await _pumpApp(tester);
    await tester.tap(find.byKey(PersistentSafetyBar.dangerButtonKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byKey(DangerCountdownSheet.silentToggleKey));
    await tester.pump();
    expect(find.text('SILENT ALERT'), findsOneWidget);

    await tester.pump(KasatConfig.dangerCountdown);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(danger.escalateCalls, 1);
    expect(danger.lastSilent, isTrue);
    expect(find.byKey(DangerCountdownSheet.queuedMessageKey), findsOneWidget);
    expect(find.textContaining('No call was placed'), findsOneWidget);
    expect(find.byKey(DangerCountdownSheet.queuedCallKey), findsOneWidget);
    expect(
      find.textContaining('Call ${KasatConfig.emergencyNumber}'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(DangerCountdownSheet.queuedCallKey));
    await tester.pump();
    expect(danger.dialerCalls, 1);
  });
}
