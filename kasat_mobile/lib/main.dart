import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'core/network_status.dart';
import 'data/attachment_store.dart';
import 'data/local_alert_repository.dart';
import 'data/local_incident_repository.dart';
import 'data/synced_incident_repository.dart';
import 'data/settings_store.dart';
import 'features/accounts/identity_store.dart';
import 'features/duress/duress_store.dart';
import 'features/vent/local_vent_repository.dart';
import 'i18n/i18n.dart';
import 'theme/kasat_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(KasatTheme.overlay);
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  final local = LocalIncidentRepository();
  await local.init();
  final repository = SyncedIncidentRepository(local: local);

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

  runApp(
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
}
