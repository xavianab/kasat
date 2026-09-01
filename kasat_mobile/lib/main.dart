import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'data/attachment_store.dart';
import 'data/local_incident_repository.dart';
import 'data/settings_store.dart';
import 'theme/kasat_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(KasatTheme.overlay);
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Swap this binding for SupabaseIncidentRepository once credentials exist;
  // nothing above the IncidentRepository interface needs to change.
  final repository = LocalIncidentRepository();
  await repository.init();

  final settings = SettingsStore();
  await settings.init();

  runApp(
    KasatApp(
      repository: repository,
      attachments: AttachmentStore(),
      settings: settings,
    ),
  );
}
