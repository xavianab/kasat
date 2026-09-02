import 'package:flutter/material.dart';
import 'package:kasat_mobile/app.dart';
import 'package:kasat_mobile/core/network_status.dart';
import 'package:kasat_mobile/data/attachment_store.dart';
import 'package:kasat_mobile/data/local_alert_repository.dart';
import 'package:kasat_mobile/data/local_incident_repository.dart';
import 'package:kasat_mobile/data/settings_store.dart';
import 'package:kasat_mobile/features/accounts/identity_store.dart';
import 'package:kasat_mobile/features/duress/duress_store.dart';
import 'package:kasat_mobile/features/vent/local_vent_repository.dart';
import 'package:kasat_mobile/features/welcome/welcome_view.dart';
import 'package:kasat_mobile/i18n/i18n.dart';
import 'package:kasat_mobile/theme/kasat_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Widget> testWelcome({bool onboard = true, Widget? home}) async {
  SharedPreferences.setMockInitialValues({});
  final settings = SettingsStore();
  await settings.init();
  if (onboard) {
    await settings.setCountryCode('ET');
    await settings.setPin('482913');
    await settings.completeOnboarding();
  }

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

  return KasatScope(
    repository: repository,
    attachments: AttachmentStore(),
    settings: settings,
    alerts: alerts,
    vents: vents,
    identity: identity,
    duress: duress,
    i18n: i18n,
    network: NetworkStatus(fakeOnline: true),
    child: MaterialApp(theme: KasatTheme.build(), home: home ?? const WelcomeView()),
  );
}
