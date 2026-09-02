import 'dart:async';

import 'package:flutter/material.dart';

import 'core/network_status.dart';
import 'data/alert_repository.dart';
import 'data/attachment_store.dart';
import 'data/incident_repository.dart';
import 'data/settings_store.dart';
import 'features/accounts/identity_store.dart';
import 'features/connectivity/background_reminder.dart';
import 'features/duress/duress_confirm_sheet.dart';
import 'features/duress/duress_store.dart';
import 'features/duress/shake_listener.dart';
import 'features/lock/lock_screen.dart';
import 'features/onboarding/onboarding_flow.dart';
import 'features/vent/vent_repository.dart';
import 'features/welcome/welcome_view.dart';
import 'i18n/i18n.dart';
import 'theme/kasat_theme.dart';

class KasatScope extends InheritedWidget {
  const KasatScope({
    super.key,
    required this.repository,
    required this.attachments,
    required this.settings,
    required this.alerts,
    required this.vents,
    required this.identity,
    required this.duress,
    required this.i18n,
    required this.network,
    required super.child,
  });

  final IncidentRepository repository;
  final AttachmentStore attachments;
  final SettingsStore settings;
  final AlertRepository alerts;
  final VentRepository vents;
  final IdentityStore identity;
  final DuressStore duress;
  final I18n i18n;
  final NetworkStatus network;

  static KasatScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<KasatScope>();
    assert(scope != null, 'KasatScope is missing above this widget.');
    return scope!;
  }

  @override
  bool updateShouldNotify(KasatScope oldWidget) =>
      repository != oldWidget.repository ||
      attachments != oldWidget.attachments ||
      settings != oldWidget.settings ||
      alerts != oldWidget.alerts ||
      vents != oldWidget.vents ||
      identity != oldWidget.identity ||
      duress != oldWidget.duress ||
      i18n != oldWidget.i18n;
}

class KasatApp extends StatefulWidget {
  const KasatApp({
    super.key,
    required this.repository,
    required this.attachments,
    required this.settings,
    required this.alerts,
    required this.vents,
    required this.identity,
    required this.duress,
    required this.i18n,
    required this.network,
  });

  final IncidentRepository repository;
  final AttachmentStore attachments;
  final SettingsStore settings;
  final AlertRepository alerts;
  final VentRepository vents;
  final IdentityStore identity;
  final DuressStore duress;
  final I18n i18n;
  final NetworkStatus network;

  @override
  State<KasatApp> createState() => _KasatAppState();
}

class _KasatAppState extends State<KasatApp> {
  final _navKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return KasatScope(
      repository: widget.repository,
      attachments: widget.attachments,
      settings: widget.settings,
      alerts: widget.alerts,
      vents: widget.vents,
      identity: widget.identity,
      duress: widget.duress,
      i18n: widget.i18n,
      network: widget.network,
      child: ListenableBuilder(
        listenable: widget.i18n,
        builder: (context, _) => MaterialApp(
          title: 'Kasat',
          navigatorKey: _navKey,
          debugShowCheckedModeBanner: false,
          theme: KasatTheme.build(),
          home: RootGate(settings: widget.settings),
          builder: (context, child) {
            final media = MediaQuery.of(context);
            return ShakeListener(
              enabled: widget.duress.hasContact,
              onShake: () {
                final contact = widget.duress.read();
                final navContext = _navKey.currentContext;
                if (contact == null || navContext == null) return;
                DuressConfirmSheet.show(navContext, contact);
              },
              child: MediaQuery(
                data: media.copyWith(
                  textScaler: TextScaler.linear(
                    media.textScaler.scale(1).clamp(0.9, 1.3),
                  ),
                ),
                child: child!,
              ),
            );
          },
        ),
      ),
    );
  }
}

class RootGate extends StatefulWidget {
  const RootGate({super.key, required this.settings});

  final SettingsStore settings;

  @override
  State<RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<RootGate> with WidgetsBindingObserver {
  bool _onboarded = false;
  bool _locked = true;
  bool _obscured = false;
  bool _online = true;
  StreamSubscription<bool>? _netSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _onboarded = widget.settings.onboardingComplete;
    const BackgroundConnectivityReminder().register();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _netSub ??= KasatScope.of(context).network.changes.listen((online) {
      if (!mounted) return;
      setState(() => _online = online);
      if (online) KasatScope.of(context).repository.flushQueued();
    });
  }

  @override
  void dispose() {
    _netSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        setState(() => _obscured = true);
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        setState(() {
          _obscured = true;
          _locked = true;
        });
      case AppLifecycleState.resumed:
        setState(() => _obscured = false);
        final scope = KasatScope.of(context);
        scope.network.isOnline().then((online) {
          if (!mounted) return;
          setState(() => _online = online);
          if (online) scope.repository.flushQueued();
        });
        scope.vents.purgeExpired();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_onboarded) {
      return OnboardingFlow(
        settings: widget.settings,
        onComplete: () => setState(() {
          _onboarded = true;
          _locked = false;
        }),
      );
    }

    if (_locked) {
      return LockScreen(
        settings: widget.settings,
        onUnlocked: () => setState(() {
          _locked = false;
          _obscured = false;
        }),
      );
    }

    if (_obscured) return const _PrivacyCover();

    return WelcomeView(offline: !_online);
  }
}

class _PrivacyCover extends StatelessWidget {
  const _PrivacyCover();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: KC.canvas,
      body: Center(child: Icon(Icons.spa_outlined, size: 34, color: KC.primary)),
    );
  }
}
