import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kasat_mobile/app.dart';
import 'package:kasat_mobile/core/kasat_config.dart';
import 'package:kasat_mobile/core/media_scrubber.dart';
import 'package:kasat_mobile/core/network_status.dart';
import 'package:kasat_mobile/core/tracking_id.dart';
import 'package:kasat_mobile/data/attachment_store.dart';
import 'package:kasat_mobile/data/local_alert_repository.dart';
import 'package:kasat_mobile/data/local_incident_repository.dart';
import 'package:kasat_mobile/data/remote_reports_client.dart';
import 'package:kasat_mobile/data/settings_store.dart';
import 'package:kasat_mobile/data/synced_incident_repository.dart';
import 'package:kasat_mobile/features/accounts/identity_store.dart';
import 'package:kasat_mobile/features/danger/danger_controller.dart';
import 'package:kasat_mobile/features/danger/danger_countdown_sheet.dart';
import 'package:kasat_mobile/features/duress/duress_store.dart';
import 'package:kasat_mobile/features/lock/pin_setup_sheet.dart';
import 'package:kasat_mobile/features/lookup/lookup_view.dart';
import 'package:kasat_mobile/features/report/receipt_view.dart';
import 'package:kasat_mobile/features/resources/emergency_contacts.dart';
import 'package:kasat_mobile/features/safety/persistent_safety_bar.dart';
import 'package:kasat_mobile/features/settings/settings_view.dart';
import 'package:kasat_mobile/features/vent/local_vent_repository.dart';
import 'package:kasat_mobile/features/welcome/welcome_view.dart';
import 'package:kasat_mobile/i18n/i18n.dart';
import 'package:kasat_mobile/models/approx_location.dart';
import 'package:kasat_mobile/models/attachment.dart';
import 'package:kasat_mobile/models/incident.dart';
import 'package:kasat_mobile/models/incident_category.dart';
import 'package:kasat_mobile/models/incident_priority.dart';
import 'package:kasat_mobile/models/incident_status.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Uint8List> _createSamplePngBytes() async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final paint = ui.Paint()..color = const ui.Color(0xFF782D5A);
  canvas.drawRect(const ui.Rect.fromLTWH(0, 0, 16, 16), paint);
  final picture = recorder.endRecording();
  final img = await picture.toImage(16, 16);
  final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
  img.dispose();
  return byteData!.buffer.asUint8List();
}

void main() {
  test('Addis Ababa sub-cities list all 11 sub-cities including Lemi Kura with Amharic', () {
    expect(kAddisAbabaSubCities.length, 11);
    final names = kAddisAbabaSubCities.map((s) => s.nameEn).toSet();
    expect(
      names,
      containsAll(<String>{
        'Bole',
        'Yeka',
        'Kirkos',
        'Arada',
        'Lideta',
        'Kolfe Keranio',
        'Gulele',
        'Addis Ketema',
        'Nifas Silk-Lafto',
        'Akaky Kaliti',
        'Lemi Kura',
      }),
    );
    final lemiKura =
        kAddisAbabaSubCities.firstWhere((s) => s.nameEn == 'Lemi Kura');
    expect(lemiKura.nameAm, 'ለሚ ኩራ');
    expect(lemiKura.bilingualLabel, 'Lemi Kura (ለሚ ኩራ)');

    final loc = ApproxLocation.fromSubCityAndLandmark(
      subCity: lemiKura.bilingualLabel,
      landmark: 'Near Ayat Roundabout',
    );
    expect(loc, isNotNull);
    expect(loc!.displayLabel, 'Lemi Kura (ለሚ ኩራ) — Near Ayat Roundabout');
  });

  test('Correction C & Hotlines: shake-to-SMS is gated off; EWLA 7711 & 991 placeholder exist', () {
    expect(KasatConfig.enableShakeToSms, isFalse);
    expect(KasatConfig.emergencyNumber, '991');
    expect(KasatConfig.ewlaGbvHotline, '7711');

    final lines = contactsForCountry('ET');
    expect(lines.any((c) => c.number == '991'), isTrue);
    expect(lines.any((c) => c.number == '7711'), isTrue);
  });

  testWidgets('Requirement E: MediaScrubber strips EXIF and computes deterministic SHA-256 hex digest', (tester) async {
    late ScrubbedMedia scrubbed1;
    late ScrubbedMedia scrubbed2;
    await tester.runAsync(() async {
      final rawPng = await _createSamplePngBytes();
      scrubbed1 = await MediaScrubber.scrubImage(rawPng);
      scrubbed2 = await MediaScrubber.scrubImage(rawPng);
    });

    expect(scrubbed1.mimeType, 'image/png');
    expect(scrubbed1.strippedMetadata, isTrue);
    expect(scrubbed1.sha256.length, 64);
    expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(scrubbed1.sha256), isTrue);
    expect(scrubbed1.sha256, equals(scrubbed2.sha256));
  });

  test('Requirement F: timeout while nominally online queues the report and flushQueued retries photo upload', () async {
    SharedPreferences.setMockInitialValues({});
    final local = LocalIncidentRepository();
    await local.init();

    final tempDir = await Directory.systemTemp.createTemp('kasat_photo_test');
    final photoFile = File('${tempDir.path}/scrubbed.png');
    await photoFile.writeAsBytes(const <int>[137, 80, 78, 71, 13, 10, 26, 10]);

    var failNetwork = true;
    var photoUploaded = false;
    var reportSent = false;

    final remote = RemoteReportsClient(
      supabaseUrl: 'https://example.supabase.co',
      supabaseAnonKey: 'test-anon-key',
      httpClient: MockClient((request) async {
        if (failNetwork) {
          throw TimeoutException('Simulated flaky connection timeout');
        }
        if (request.url.path.contains('/functions/v1/upload-evidence')) {
          photoUploaded = true;
          return http.Response(
            '{"object_key":"KST-FLAKY/photo.png","tracking_code":"KST-FLAKY","server_sha256":"abc123sha","integrity_status":"verified"}',
            200,
          );
        }
        if (request.url.path.endsWith('/rpc/create_draft_report')) {
          return http.Response(
            '{"tracking_code":"KST-FLAKY","access_secret":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","incident_type":"HRSMT","approx_location":"Bole (ቦሌ)","description":"Flaky connection test description long enough","photo_url":null,"status":"draft","sent_at":null,"created_at":"2026-10-20T12:00:00Z"}',
            200,
            headers: const {'content-type': 'application/json; charset=utf-8'},
          );
        }
        if (request.url.path.endsWith('/rpc/send_draft_report') ||
            request.url.path.endsWith('/rpc/lookup_own_report')) {
          reportSent = request.url.path.endsWith('/rpc/send_draft_report') || reportSent;
          return http.Response(
            '{"tracking_code":"KST-FLAKY","access_secret":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","incident_type":"HRSMT","approx_location":"Bole (ቦሌ)","description":"Flaky connection test description long enough","photo_url":"KST-FLAKY/photo.png","evidence_sha256":"abc123sha","status":"sent","sent_at":"2026-10-20T12:01:00Z","created_at":"2026-10-20T12:00:00Z"}',
            200,
            headers: const {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response('{}', 200);
      }),
    );

    final synced = SyncedIncidentRepository(local: local, remote: remote);

    final draft = IncidentDraft(
      category: IncidentCategory.harassment,
      description: 'Flaky connection test description long enough to pass validation.',
      priority: IncidentPriority.medium,
      countryCode: 'ET',
      attachments: [
        Attachment(
          id: 'att-1',
          label: 'Evidence 1',
          mimeType: 'image/png',
          byteSize: 8,
          storagePath: photoFile.path,
          strippedMetadata: true,
          sha256: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        ),
      ],
    );

    // Nominally online (offline: false), but remote times out -> must be marked queued!
    final submitted = await synced.submit(draft, trackingId: 'KST-FLAKY', offline: false);
    expect(submitted.status, IncidentStatus.queued);
    expect(await synced.queuedCount(), 1);

    // Now connection recovers; flushQueued() uploads photo and marks report sent
    failNetwork = false;
    final flushed = await synced.flushQueued();
    expect(flushed, 1);
    expect(photoUploaded, isTrue);
    expect(reportSent, isTrue);

    final afterFlush = await synced.lookup('KST-FLAKY');
    expect(afterFlush?.status, IncidentStatus.sent);
    expect(afterFlush?.serverCreatedAtUtc, isNotNull);

    await tempDir.delete(recursive: true);
  });

  test('Emergency dispatch and one-way identity reveal work end-to-end', () async {
    SharedPreferences.setMockInitialValues({});
    final local = LocalIncidentRepository();
    await local.init();

    var emergencyInserted = false;
    var identityRevealedRpcCalled = false;

    final remote = RemoteReportsClient(
      supabaseUrl: 'https://example.supabase.co',
      supabaseAnonKey: 'test-anon-key',
      httpClient: MockClient((request) async {
        if (request.url.path.contains('/functions/v1/emergency-alert')) {
          emergencyInserted = request.body.contains('"p_device_secret"');
          return http.Response(
            '{"tracking_code":"KST-EMG01","access_secret":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","incident_type":"CRTCL","description":"EMERGENCY","status":"sent","is_emergency":true,"live_location_active":true,"created_at":"2026-10-20T12:00:00Z"}',
            200,
          );
        }
        if (request.url.path.endsWith('/rpc/reveal_report_identity')) {
          identityRevealedRpcCalled = true;
          expect(request.body, contains('p_access_secret'));
          return http.Response('{"ok":true,"tracking_code":"KST-EMG01"}', 200);
        }
        return http.Response('[]', 200);
      }),
    );

    final synced = SyncedIncidentRepository(local: local, remote: remote);

    final emg = await synced.triggerEmergency(
      trackingId: 'KST-EMG01',
      countryCode: 'ET',
      latitude: 9.0105,
      longitude: 38.7891,
    );
    expect(emergencyInserted, isTrue);
    expect(emg.isEmergency, isTrue);
    expect(emg.liveLocationActive, isTrue);

    final revealed = await synced.revealIdentity(
      emg.trackingId,
      fullName: 'Selam T.',
      channel: 'phone',
      handle: '+251911000000',
      safeNote: 'Weekday mornings',
    );
    expect(identityRevealedRpcCalled, isTrue);
    expect(revealed?.identityRevealed, isTrue);
  });

  testWidgets('Zero-setup launch opens Welcome directly with PersistentSafetyBar (I\'M IN DANGER + Quick exit)', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsStore();
    await settings.init();
    final repository = LocalIncidentRepository();
    await repository.init();
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
        network: NetworkStatus(fakeOnline: true),
      ),
    );
    await tester.pumpAndSettle();

    // Opens directly to WelcomeView with zero setup or PIN prompt on launch
    expect(find.byKey(PersistentSafetyBar.dangerButtonKey), findsOneWidget);
    expect(find.byKey(PersistentSafetyBar.quickExitButtonKey), findsOneWidget);
    expect(find.text("I'M IN DANGER"), findsOneWidget);
    expect(find.text('Quick exit'), findsOneWidget);
    expect(find.text('Tell us what happened'), findsOneWidget);
  });

  test('Issue 1 & 6: Foreground notification text is neutral & Quick Exit does not open browser', () {
    expect(KasatConfig.foregroundNotificationTitle, 'System service running');
    expect(KasatConfig.foregroundNotificationBody, 'Background sync is active');
    expect(KasatConfig.foregroundNotificationIcon, 'ic_stat_sync');
    expect(
      KasatConfig.foregroundNotificationTitle.toLowerCase(),
      isNot(contains('kasat')),
    );
    expect(
      KasatConfig.foregroundNotificationTitle.toLowerCase(),
      isNot(contains('location')),
    );
    expect(
      KasatConfig.foregroundNotificationBody.toLowerCase(),
      isNot(contains('location')),
    );
    expect(KasatConfig.quickExitOpensBrowser, isFalse);

    final locSettings = DangerController.buildStreamLocationSettings();
    expect(locSettings, isNotNull);
  });

  test('Issue 2: Server-side evidence hashing computes authoritative SHA-256 and verifies client transport hash', () async {
    SharedPreferences.setMockInitialValues({});
    final local = LocalIncidentRepository();
    await local.init();

    final tempDir = await Directory.systemTemp.createTemp('kasat_server_hash_test');
    final photoFile = File('${tempDir.path}/evidence.png');
    await photoFile.writeAsBytes(const <int>[137, 80, 78, 71, 13, 10, 26, 10]);

    const clientHash =
        '894f2d11b13458b3536291a82208c2072909d5fa75f87a900a08bf2078073f25';
    const serverComputedHash =
        '894f2d11b13458b3536291a82208c2072909d5fa75f87a900a08bf2078073f25';

    var verifyEdgeFunctionCalled = false;

    final remote = RemoteReportsClient(
      supabaseUrl: 'https://example.supabase.co',
      supabaseAnonKey: 'test-anon-key',
      httpClient: MockClient((request) async {
        if (request.url.path.contains('/functions/v1/upload-evidence')) {
          verifyEdgeFunctionCalled = true;
          return http.Response(
            '{"object_key":"KST-SHASH/att-1.png","tracking_code":"KST-SHASH","server_sha256":"$serverComputedHash","client_sha256":"$clientHash","integrity_status":"verified","verified_at":"2026-10-20T15:00:01Z"}',
            200,
          );
        }
        if (request.url.path.endsWith('/rpc/create_draft_report')) {
          expect(request.body.contains('"evidence_sha256"'), isFalse);
          expect(request.body.contains('"p_client_sha256":"$clientHash"'), isTrue);
          return http.Response(
            '{"tracking_code":"KST-SHASH","access_secret":"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd","incident_type":"HRSMT","description":"Server hash verification test description long enough","photo_url":null,"evidence_sha256":null,"client_evidence_sha256":"$clientHash","evidence_integrity_status":"pending_server_hash","status":"draft","created_at":"2026-10-20T15:00:00Z"}',
            200,
          );
        }
        if (request.url.path.endsWith('/rpc/lookup_own_report')) {
          return http.Response(
            '{"tracking_code":"KST-SHASH","access_secret":"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd","evidence_sha256":"$serverComputedHash","client_evidence_sha256":"$clientHash","evidence_integrity_status":"verified","evidence_verified_at":"2026-10-20T15:00:01Z","status":"draft"}',
            200,
          );
        }
        return http.Response('{}', 200);
      }),
    );

    final synced = SyncedIncidentRepository(local: local, remote: remote);
    final draft = IncidentDraft(
      category: IncidentCategory.harassment,
      description: 'Server hash verification test description long enough to pass.',
      priority: IncidentPriority.medium,
      countryCode: 'ET',
      attachments: [
        Attachment(
          id: 'att-1',
          label: 'Evidence 1',
          mimeType: 'image/png',
          byteSize: 8,
          storagePath: photoFile.path,
          strippedMetadata: true,
          sha256: clientHash,
        ),
      ],
    );

    final submitted = await synced.submit(draft, trackingId: 'KST-SHASH', offline: false);
    expect(verifyEdgeFunctionCalled, isTrue);
    expect(submitted.clientEvidenceSha256, clientHash);
    expect(submitted.evidenceSha256, serverComputedHash);
    expect(submitted.evidenceIntegrityStatus, 'verified');
    expect(submitted.evidenceVerifiedAtUtc, isNotNull);

    await tempDir.delete(recursive: true);
  });

  testWidgets('Issue 3: Tracking code lookup is NOT gated behind PIN; PIN gates only saved-history list; Receipt insists on writing code before PIN; PIN setup warns about recovery', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsStore();
    await settings.init();
    final repository = LocalIncidentRepository();
    await repository.init();
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

    // Add a saved report so localTrackingIds is non-empty
    final saved = await repository.submit(
      const IncidentDraft(
        category: IncidentCategory.harassment,
        description: 'A saved report description that is at least forty characters long.',
        priority: IncidentPriority.medium,
        countryCode: 'ET',
      ),
      trackingId: 'KST-7P4M9',
    );

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
        network: NetworkStatus(fakeOnline: true),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    // Navigate to "Check my case" -> LookupView
    await tester.tap(find.text('Check my case'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    // 1. Saved history list is locked behind PIN, so KST-7P4M9 chip is NOT shown
    expect(find.byKey(const Key('unlock-history-button')), findsOneWidget);
    expect(find.text('KST-7P4M9'), findsNothing);

    // 2. Typing a valid tracking code directly works WITHOUT any PIN prompt!
    expect(find.byType(LookupView), findsOneWidget);
    await tester.enterText(
      find.descendant(
        of: find.byType(LookupView),
        matching: find.byType(TextField),
      ),
      'KST-4RT7Q',
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Look it up'));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.drag(
      find.descendant(
        of: find.byType(LookupView),
        matching: find.byType(ListView),
      ),
      const Offset(0, -300),
    );
    await tester.pump(const Duration(milliseconds: 200));

    // Case KST-4RT7Q opens immediately without asking for a PIN!
    expect(find.text('Your case'), findsOneWidget);
    expect(find.text('What has happened so far'), findsOneWidget);

    // 3. Verify ReceiptView shows tracking code BEFORE PIN and insists she write it down
    await tester.pumpWidget(
      KasatScope(
        repository: repository,
        attachments: AttachmentStore(),
        settings: settings,
        alerts: alerts,
        vents: vents,
        identity: identity,
        duress: duress,
        i18n: i18n,
        network: NetworkStatus(fakeOnline: true),
        child: MaterialApp(
          home: ReceiptView(incident: saved, onTrack: () {}),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('KST-7P4M9'), findsOneWidget);
    expect(find.byKey(ReceiptView.wroteDownConfirmKey), findsOneWidget);
    expect(settings.hasPin, isFalse);

    // Confirm she wrote down the tracking code -> Step 2 button to set PIN appears
    await tester.ensureVisible(find.byKey(ReceiptView.wroteDownConfirmKey));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(ReceiptView.wroteDownConfirmKey));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(ReceiptView.setPinAfterCodeKey), findsOneWidget);

    // Open PIN setup and verify explicit warning banner is shown
    await tester.ensureVisible(find.byKey(ReceiptView.setPinAfterCodeKey));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(ReceiptView.setPinAfterCodeKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(PinSetupScreen.warningBannerKey), findsOneWidget);
    expect(
      find.textContaining('Forgetting this PIN means losing access to the saved-reports list'),
      findsOneWidget,
    );
  });

  testWidgets('Issue 5: Danger button visibility toggles between full visible bar and discreet long-press dot', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsStore();
    await settings.init();
    final repository = LocalIncidentRepository();
    await repository.init();
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
        network: NetworkStatus(fakeOnline: true),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    // Default is visible mode
    expect(settings.dangerBarMode, DangerBarMode.visible);
    expect(find.text("I'M IN DANGER"), findsOneWidget);
    expect(find.byKey(PersistentSafetyBar.discreetDangerDotKey), findsNothing);

    // Switch to discreet mode
    await settings.setDangerBarMode(DangerBarMode.discreet);
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
        network: NetworkStatus(fakeOnline: true),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    // "I'M IN DANGER" text is hidden; unlabeled dot is present and opens emergency sheet on long press
    expect(find.text("I'M IN DANGER"), findsNothing);
    expect(find.byKey(PersistentSafetyBar.discreetDangerDotKey), findsOneWidget);
    expect(find.byKey(SettingsView.dangerModeDiscreetKey), findsNothing);

    await tester.longPress(find.byKey(PersistentSafetyBar.dangerButtonKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('EMERGENCY ESCALATION'), findsOneWidget);

    await tester.tap(find.byKey(DangerCountdownSheet.cancelButtonKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets(
    'Officer Silent Approach Confirmation: vibrates ONCE on arrival (no audio), shows two large buttons, and records response',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsStore();
      await settings.init();
      final repository = LocalIncidentRepository();
      await repository.init();
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

      final danger = DangerController(
        repository: repository,
        settings: settings,
        network: NetworkStatus(fakeOnline: true),
      );

      final platformCalls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        platformCalls.add(call.method);
        return null;
      });

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
          network: NetworkStatus(fakeOnline: true),
          danger: danger,
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      // 1. Trigger silent emergency escalation
      late Incident emergency;
      await tester.runAsync(() async {
        emergency = await danger.escalateNow(silent: true);
      });
      expect(emergency.isEmergency, isTrue);
      expect(emergency.silentMode, isTrue);
      await tester.pump(const Duration(milliseconds: 200));

      // Before officer arrives, approach confirmation buttons are not shown
      expect(find.byKey(PersistentSafetyBar.approachPromptCardKey), findsNothing);
      expect(danger.arrivalVibrationCount, 0);

      // 2. Officer taps "I have arrived" on the portal
      platformCalls.clear();
      await tester.runAsync(() async {
        await repository.simulateOfficerArrival(emergency.trackingId, windowSec: 90);
        await danger.checkOfficerArrivalNow();
      });
      await tester.pump(const Duration(milliseconds: 200));

      // Phone vibrates ONCE and ONLY ONCE; zero SystemSound.play calls
      expect(danger.arrivalVibrationCount, 1);
      expect(
        platformCalls.where((m) => m == 'HapticFeedback.vibrate').length,
        1,
      );
      expect(
        platformCalls.where((m) => m.startsWith('SystemSound')).isEmpty,
        isTrue,
      );

      // Subsequent poll checks do NOT vibrate again
      await tester.runAsync(() async {
        await danger.checkOfficerArrivalNow();
        await danger.checkOfficerArrivalNow();
      });
      expect(danger.arrivalVibrationCount, 1);
      expect(
        platformCalls.where((m) => m == 'HapticFeedback.vibrate').length,
        1,
      );

      // 3. When she opens the app, she sees the two large approach buttons
      expect(find.byKey(PersistentSafetyBar.approachPromptCardKey), findsOneWidget);
      expect(find.text('I can come out'), findsOneWidget);
      expect(find.text('He is here — do not knock'), findsOneWidget);

      // 4. She taps "He is here — do not knock"
      await tester.tap(find.byKey(PersistentSafetyBar.doNotKnockButtonKey));
      await tester.pump(const Duration(milliseconds: 200));

      expect(danger.approachResponse, 'abuser_present_do_not_knock');
      late Incident? updated;
      await tester.runAsync(() async {
        updated = await repository.lookup(emergency.trackingId);
        await danger.stopLiveLocation();
      });
      expect(updated?.approachResponse, 'abuser_present_do_not_knock');

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    },
  );

  testWidgets(
    'Welcome screen fixes: top-bar Amharic/English toggle, Notices & Hotlines & support labels, EWLA 7711 note, and zero overflow at largest text scale in both languages',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(393, 852));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      SharedPreferences.setMockInitialValues({});
      final settings = SettingsStore();
      await settings.init();
      final repository = LocalIncidentRepository();
      await repository.init();
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
      final network = NetworkStatus(fakeOnline: true);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(393, 852),
            textScaler: TextScaler.linear(2.0),
          ),
          child: KasatApp(
            repository: repository,
            attachments: AttachmentStore(),
            settings: settings,
            alerts: alerts,
            vents: vents,
            identity: identity,
            duress: duress,
            i18n: i18n,
            network: network,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Language toggle visible on Welcome screen without opening More menu
      expect(find.byKey(WelcomeView.languageToggleKey), findsOneWidget);
      expect(find.text('አማርኛ / English'), findsOneWidget);

      // 2. Shortened "Notices" and renamed "Hotlines & support" + EWLA 7711 note
      expect(find.text('Notices'), findsOneWidget);
      expect(find.text('Hotlines & support'), findsOneWidget);
      expect(
        find.textContaining('EWLA 7711 and other support lines, not police'),
        findsOneWidget,
      );

      // 3. Tapping language toggle switches every string on Welcome to Amharic
      await tester.tap(find.byKey(WelcomeView.languageToggleKey));
      await tester.pumpAndSettle();

      expect(i18n.code, 'am');
      expect(find.text('ያለ ፍርሃት\nተናገሪ።'), findsOneWidget);
      expect(find.text('የምንገባው ቃል'), findsOneWidget);
      expect(find.text('ምንም ነገር ወደ አንቺ አይመራም'), findsOneWidget);
      expect(find.text('ፎቶዎች መጀመሪያ ይጸዳሉ'), findsOneWidget);
      expect(find.text('የእርዳታ መስመሮች'), findsOneWidget);
      expect(find.text('ማስታወቂያዎች'), findsOneWidget);
      expect(find.textContaining('EWLA 7711'), findsOneWidget);
    },
  );

  testWidgets(
    'LIVE SUPABASE E2E: offline-to-online flush, server-side SHA-256 verification, and officer RLS draft invisibility',
    (tester) async {
      await tester.runAsync(() async {
        HttpOverrides.global = null;
        SharedPreferences.setMockInitialValues({});
        const supabaseUrl = String.fromEnvironment('KASAT_SUPABASE_URL');
        const anonKey = String.fromEnvironment('KASAT_SUPABASE_ANON_KEY');
        const officerEmail = String.fromEnvironment('KASAT_LIVE_OFFICER_EMAIL');
        const officerPassword =
            String.fromEnvironment('KASAT_LIVE_OFFICER_PASSWORD');
        expect(supabaseUrl, isNotEmpty);
        expect(anonKey, isNotEmpty);
        expect(
          supabaseUrl.contains('itjyuvzjgtyakomreghv'),
          isFalse,
          reason: 'Live tests must never target kasat-production',
        );
        expect(officerEmail, isNotEmpty);
        expect(officerPassword, isNotEmpty);

        final local = LocalIncidentRepository();
        await local.init();
        final remote = RemoteReportsClient(
          supabaseUrl: supabaseUrl,
          supabaseAnonKey: anonKey,
        );
        final synced = SyncedIncidentRepository(local: local, remote: remote);

        final tempDir =
            await Directory.systemTemp.createTemp('kasat_live_e2e_');
        final rawPng = await _createSamplePngBytes();
        final scrubbed = await MediaScrubber.scrubImage(rawPng);
        final photoFile = File('${tempDir.path}/scrubbed.png');
        await photoFile.writeAsBytes(scrubbed.bytes);

        final flushTrackingId = TrackingId.generate();
        final draftTrackingId = TrackingId.generate();

        // 1. Submit OFFLINE -> status is queued locally, not on remote yet
        final draft = IncidentDraft(
          category: IncidentCategory.harassment,
          description:
              'Live E2E offline-to-online flush test with server-side SHA-256 verification.',
          priority: IncidentPriority.high,
          countryCode: 'ET',
          location: ApproxLocation.fromSubCityAndLandmark(
            subCity: 'Bole (ቦሌ)',
            landmark: 'Bole Medhanialem',
          ),
          attachments: [
            Attachment(
              id: 'att-live-1',
              label: 'Evidence 1',
              mimeType: scrubbed.mimeType,
              byteSize: scrubbed.bytes.length,
              storagePath: photoFile.path,
              strippedMetadata: true,
              sha256: scrubbed.sha256,
            ),
          ],
        );

        final queued = await synced.submit(
          draft,
          trackingId: flushTrackingId,
          offline: true,
        );
        expect(queued.status, IncidentStatus.queued);
        final beforeFlushRemote = await remote.lookup(flushTrackingId, null);
        expect(beforeFlushRemote, isNull);

        // 2. Go ONLINE and call flushQueued() -> uploads photo, runs verify-evidence Edge Function, marks sent
        final flushedCount = await synced.flushQueued();
        expect(flushedCount, greaterThanOrEqualTo(1));

        final afterFlushRemote = await remote.lookup(
          flushTrackingId,
          await local.lookup(flushTrackingId),
        );
        expect(afterFlushRemote, isNotNull);
        expect(afterFlushRemote!.status, IncidentStatus.sent);
        expect(afterFlushRemote.clientEvidenceSha256, scrubbed.sha256);
        expect(afterFlushRemote.evidenceSha256, scrubbed.sha256);
        expect(afterFlushRemote.evidenceIntegrityStatus, 'verified');
        expect(afterFlushRemote.evidenceVerifiedAtUtc, isNotNull);

        // 3. Create a remote 'draft' row (not yet sent) and verify police cannot see it
        final draftIncident = await local.submit(
          draft,
          trackingId: draftTrackingId,
          offline: true,
        );
        await remote.insertDraft(
          draftIncident.copyWith(attachments: const []),
        );

        // 4. Sign in as actual Police Officer (Inspector Meron Haile, Bole Sub-City) and verify RLS
        final httpClient = http.Client();
        final authResp = await httpClient.post(
          Uri.parse('$supabaseUrl/auth/v1/token?grant_type=password'),
          headers: {
            'apikey': anonKey,
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'email': officerEmail,
            'password': officerPassword,
          }),
        );
        expect(authResp.statusCode, 200);
        expect(authResp.body, contains('access_token'));
        final tokenMatch = RegExp(r'"access_token"\s*:\s*"([^"]+)"')
            .firstMatch(authResp.body);
        final officerJwt = tokenMatch!.group(1)!;

        // Officer queries the DRAFT tracking code -> MUST return empty array [] (RLS blocks drafts from police!)
        final officerDraftResp = await httpClient.get(
          Uri.parse(
            '$supabaseUrl/rest/v1/reports?tracking_code=eq.$draftTrackingId&select=tracking_code,status',
          ),
          headers: {
            'apikey': anonKey,
            'Authorization': 'Bearer $officerJwt',
          },
        );
        expect(officerDraftResp.statusCode, 200);
        expect(officerDraftResp.body.trim(), '[]');

        // Officer queries the SENT tracking code -> returns the row with verified server SHA-256
        final officerSentResp = await httpClient.get(
          Uri.parse(
            '$supabaseUrl/rest/v1/reports?tracking_code=eq.$flushTrackingId&select=tracking_code,status,evidence_sha256,client_evidence_sha256,evidence_integrity_status,evidence_verified_at',
          ),
          headers: {
            'apikey': anonKey,
            'Authorization': 'Bearer $officerJwt',
          },
        );
        expect(officerSentResp.statusCode, 200);
        expect(officerSentResp.body, contains(flushTrackingId));
        expect(
          officerSentResp.body,
          contains('"evidence_integrity_status":"verified"'),
        );
        expect(
          officerSentResp.body,
          contains('"evidence_sha256":"${scrubbed.sha256}"'),
        );

        // 5. LIVE E2E Officer Silent Approach Confirmation, Coalescing Rate-Limiter,
        //    Dispatch Lifecycle (new -> claimed -> en_route -> on_scene -> resolved),
        //    and report_audit_log check
        final emgCode = TrackingId.generate();
        final emgCodeDuplicate = TrackingId.generate();
        final deviceSecret =
            'e2e-dev-secret-${DateTime.now().millisecondsSinceEpoch}-xxxxxxxx';

        expect(KasatConfig.demoSurvivorLatitude, closeTo(8.9950, 0.0001));
        expect(KasatConfig.demoSurvivorLongitude, closeTo(38.7890, 0.0001));
        final firstEmgResp = await httpClient.post(
          Uri.parse('$supabaseUrl/functions/v1/emergency-alert'),
          headers: {
            'apikey': anonKey,
            'Authorization': 'Bearer $anonKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'p_tracking_code': emgCode,
            'p_approx_location': KasatConfig.demoSurvivorLandmark,
            'p_description':
                'Urgent silent alert in Bole sub-city requiring immediate dispatch verification.',
            'p_silent_mode': true,
            'p_latitude': KasatConfig.demoSurvivorLatitude,
            'p_longitude': KasatConfig.demoSurvivorLongitude,
            'p_accuracy_meters': 8.5,
            'p_device_secret': deviceSecret,
          }),
        );
        expect(firstEmgResp.statusCode, 200);
        expect(firstEmgResp.body, contains('"dispatch_status":"new"'));
        expect(firstEmgResp.body, contains('"access_secret"'));
        final firstEmgJson =
            jsonDecode(firstEmgResp.body) as Map<String, dynamic>;
        final liveEmgCode = firstEmgJson['tracking_code'] as String;
        final liveAccessSecret = firstEmgJson['access_secret'] as String;

        final coalesceResp = await httpClient.post(
          Uri.parse('$supabaseUrl/functions/v1/emergency-alert'),
          headers: {
            'apikey': anonKey,
            'Authorization': 'Bearer $anonKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'p_tracking_code': emgCodeDuplicate,
            'p_approx_location': KasatConfig.demoSurvivorLandmark,
            'p_description':
                'Urgent silent alert in Bole sub-city requiring immediate dispatch verification.',
            'p_silent_mode': true,
            'p_latitude': KasatConfig.demoSurvivorLatitude,
            'p_longitude': KasatConfig.demoSurvivorLongitude,
            'p_accuracy_meters': 8.5,
            'p_device_secret': deviceSecret,
          }),
        );
        expect(coalesceResp.statusCode, 200);
        expect(coalesceResp.body, contains('"tracking_code":"$liveEmgCode"'));
        expect(coalesceResp.body, contains('"activation_count":2'));

        // Officer claims the alert (new -> claimed) and transitions to en_route
        final claimResp = await httpClient.post(
          Uri.parse('$supabaseUrl/rest/v1/rpc/transition_report_dispatch'),
          headers: {
            'apikey': anonKey,
            'Authorization': 'Bearer $officerJwt',
            'Content-Type': 'application/json',
          },
          body:
              '{"p_tracking_code":"$liveEmgCode","p_next_status":"claimed"}',
        );
        expect(claimResp.statusCode, 200);
        expect(claimResp.body, contains('"dispatch_status":"claimed"'));

        final enRouteResp = await httpClient.post(
          Uri.parse('$supabaseUrl/rest/v1/rpc/transition_report_dispatch'),
          headers: {
            'apikey': anonKey,
            'Authorization': 'Bearer $officerJwt',
            'Content-Type': 'application/json',
          },
          body:
              '{"p_tracking_code":"$liveEmgCode","p_next_status":"en_route"}',
        );
        expect(enRouteResp.statusCode, 200);
        expect(enRouteResp.body, contains('"dispatch_status":"en_route"'));

        // Officer taps "I have arrived" via signal_officer_arrived RPC (transitions to on_scene)
        final arriveResp = await httpClient.post(
          Uri.parse('$supabaseUrl/rest/v1/rpc/signal_officer_arrived'),
          headers: {
            'apikey': anonKey,
            'Authorization': 'Bearer $officerJwt',
            'Content-Type': 'application/json',
          },
          body: '{"p_tracking_code":"$liveEmgCode","p_window_sec":90}',
        );
        expect(arriveResp.statusCode, 200);
        expect(arriveResp.body, contains('"silent_mode":true'));
        expect(arriveResp.body, contains('"officer_arrived_at":'));
        expect(arriveResp.body, contains('"dispatch_status":"on_scene"'));

        final afterArrival = await httpClient.post(
          Uri.parse('$supabaseUrl/rest/v1/rpc/lookup_own_report'),
          headers: {
            'apikey': anonKey,
            'Authorization': 'Bearer $anonKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'p_access_secret': liveAccessSecret}),
        );
        expect(afterArrival.statusCode, 200);
        expect(afterArrival.body, contains('officer_arrived_at'));

        final afterSurvivorReply = await httpClient.post(
          Uri.parse('$supabaseUrl/rest/v1/rpc/submit_approach_response'),
          headers: {
            'apikey': anonKey,
            'Authorization': 'Bearer $anonKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'p_access_secret': liveAccessSecret,
            'p_response': 'abuser_present_do_not_knock',
          }),
        );
        expect(afterSurvivorReply.statusCode, 200);
        expect(afterSurvivorReply.body, contains('abuser_present_do_not_knock'));

        final resolveResp = await httpClient.post(
          Uri.parse('$supabaseUrl/rest/v1/rpc/transition_report_dispatch'),
          headers: {
            'apikey': anonKey,
            'Authorization': 'Bearer $officerJwt',
            'Content-Type': 'application/json',
          },
          body:
              '{"p_tracking_code":"$liveEmgCode","p_next_status":"resolved","p_note":"E2E verification completed"}',
        );
        expect(resolveResp.statusCode, 200);
        expect(resolveResp.body, contains('"dispatch_status":"resolved"'));

        // Also resolve the flushed standard report so the live queue stays clean
        await httpClient.post(
          Uri.parse('$supabaseUrl/rest/v1/rpc/transition_report_dispatch'),
          headers: {
            'apikey': anonKey,
            'Authorization': 'Bearer $officerJwt',
            'Content-Type': 'application/json',
          },
          body:
              '{"p_tracking_code":"$flushTrackingId","p_next_status":"claimed"}',
        );
        await httpClient.post(
          Uri.parse('$supabaseUrl/rest/v1/rpc/transition_report_dispatch'),
          headers: {
            'apikey': anonKey,
            'Authorization': 'Bearer $officerJwt',
            'Content-Type': 'application/json',
          },
          body:
              '{"p_tracking_code":"$flushTrackingId","p_next_status":"resolved"}',
        );

        // Verify report_audit_log recorded every transition
        final auditResp = await httpClient.get(
          Uri.parse(
            '$supabaseUrl/rest/v1/report_audit_log?select=action,created_at&order=created_at.desc&limit=15',
          ),
          headers: {
            'apikey': anonKey,
            'Authorization': 'Bearer $officerJwt',
          },
        );
        expect(auditResp.statusCode, 200);
        expect(auditResp.body, contains('emergency_coalesced_heartbeat'));
        expect(auditResp.body, contains('dispatch_claimed'));
        expect(auditResp.body, contains('dispatch_en_route'));
        expect(auditResp.body, contains('officer_arrived'));
        expect(auditResp.body, contains('approach_response_do_not_knock'));
        expect(auditResp.body, contains('dispatch_resolved'));

        // ignore: avoid_print
        print(
          'LIVE_E2E_PROOF: flushed=$flushTrackingId draft=$draftTrackingId '
          'emg=$liveEmgCode '
          'officerDraftBody=${officerDraftResp.body} '
          'officerSentBody=${officerSentResp.body} '
          'auditBody=${auditResp.body}',
        );

        httpClient.close();
        await tempDir.delete(recursive: true);
      });
    },
    skip: !const bool.fromEnvironment('KASAT_LIVE_SUPABASE_TEST'),
  );
}
