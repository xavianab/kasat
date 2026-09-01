import 'package:flutter/material.dart';

import 'data/attachment_store.dart';
import 'data/incident_repository.dart';
import 'features/welcome/welcome_view.dart';
import 'theme/kasat_theme.dart';

/// Dependency handoff for the MVP. Deliberately a plain InheritedWidget —
/// there are two dependencies and adding a DI container would be more moving
/// parts than the app has state.
class KasatScope extends InheritedWidget {
  const KasatScope({
    super.key,
    required this.repository,
    required this.attachments,
    required super.child,
  });

  final IncidentRepository repository;
  final AttachmentStore attachments;

  static KasatScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<KasatScope>();
    assert(scope != null, 'KasatScope is missing above this widget.');
    return scope!;
  }

  @override
  bool updateShouldNotify(KasatScope oldWidget) =>
      repository != oldWidget.repository || attachments != oldWidget.attachments;
}

class KasatApp extends StatelessWidget {
  const KasatApp({
    super.key,
    required this.repository,
    required this.attachments,
  });

  final IncidentRepository repository;
  final AttachmentStore attachments;

  @override
  Widget build(BuildContext context) {
    return KasatScope(
      repository: repository,
      attachments: attachments,
      child: MaterialApp(
        title: 'Kasat',
        debugShowCheckedModeBanner: false,
        theme: KasatTheme.build(),
        home: const WelcomeView(),
        builder: (context, child) {
          // Lock text scaling. The layouts are dense by design and a 2x system
          // scale would push critical actions off-screen.
          final media = MediaQuery.of(context);
          return MediaQuery(
            data: media.copyWith(
              textScaler: TextScaler.linear(
                media.textScaler.scale(1).clamp(0.9, 1.2),
              ),
            ),
            child: child!,
          );
        },
      ),
    );
  }
}
