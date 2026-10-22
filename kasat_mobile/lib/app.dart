import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'core/kasat_config.dart';
import 'core/network_status.dart';
import 'data/alert_repository.dart';
import 'data/attachment_store.dart';
import 'data/incident_repository.dart';
import 'data/settings_store.dart';
import 'features/accounts/identity_store.dart';
import 'features/connectivity/background_reminder.dart';
import 'features/danger/danger_controller.dart';
import 'features/danger/danger_countdown_sheet.dart';
import 'features/duress/duress_confirm_sheet.dart';
import 'features/duress/duress_store.dart';
import 'features/duress/shake_listener.dart';
import 'features/safety/persistent_safety_bar.dart';
import 'features/vent/vent_repository.dart';
import 'features/welcome/welcome_view.dart';
import 'i18n/i18n.dart';
import 'platform/app_disguise_channel.dart';
import 'theme/kasat_theme.dart';

class KasatScope extends InheritedWidget {
  KasatScope({
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
    DangerController? danger,
    this.isPinSessionUnlocked = false,
    this.settingsRevision = 0,
    VoidCallback? unlockPinSession,
    VoidCallback? lockPinSession,
    VoidCallback? notifySettingsChanged,
    void Function(VoidCallback callback)? registerWipeCallback,
    void Function(VoidCallback callback)? unregisterWipeCallback,
    Future<void> Function()? triggerQuickExit,
    required super.child,
  })  : danger = danger ??
            DangerController(
              repository: repository,
              settings: settings,
              network: network,
            ),
        unlockPinSession = unlockPinSession ?? _noop,
        lockPinSession = lockPinSession ?? _noop,
        notifySettingsChanged = notifySettingsChanged ?? _noop,
        registerWipeCallback = registerWipeCallback ?? _noopWipe,
        unregisterWipeCallback = unregisterWipeCallback ?? _noopWipe,
        triggerQuickExit = triggerQuickExit ?? _noopAsync;

  static void _noop() {}
  static void _noopWipe(VoidCallback _) {}
  static Future<void> _noopAsync() async {}

  final IncidentRepository repository;
  final AttachmentStore attachments;
  final SettingsStore settings;
  final AlertRepository alerts;
  final VentRepository vents;
  final IdentityStore identity;
  final DuressStore duress;
  final I18n i18n;
  final NetworkStatus network;
  final DangerController danger;

  /// True after the survivor creates or enters her 6-digit PIN in the current
  /// foreground session. Resets to false on backgrounding or Quick Exit.
  final bool isPinSessionUnlocked;
  final int settingsRevision;
  final VoidCallback unlockPinSession;
  final VoidCallback lockPinSession;
  final VoidCallback notifySettingsChanged;

  /// Allows screens with in-memory form state to register a wipe handler invoked
  /// immediately when Quick Exit is pressed.
  final void Function(VoidCallback callback) registerWipeCallback;
  final void Function(VoidCallback callback) unregisterWipeCallback;
  final Future<void> Function() triggerQuickExit;

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
      i18n != oldWidget.i18n ||
      danger != oldWidget.danger ||
      isPinSessionUnlocked != oldWidget.isPinSessionUnlocked ||
      settingsRevision != oldWidget.settingsRevision;
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
    this.danger,
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
  final DangerController? danger;

  @override
  State<KasatApp> createState() => _KasatAppState();
}

class _KasatAppState extends State<KasatApp> {
  static const _privacyChannel = MethodChannel('app.kasat/privacy');

  final _navKey = GlobalKey<NavigatorState>();
  final _wipeCallbacks = <VoidCallback>{};
  late final DangerController _danger = widget.danger ??
      DangerController(
        repository: widget.repository,
        settings: widget.settings,
        network: widget.network,
      );
  bool _pinSessionUnlocked = false;
  int _settingsRevision = 0;

  @override
  void initState() {
    super.initState();
    _clearHazardousDisguiseIfSet();
  }

  /// Safety fix B: An icon swap without a functioning decoy interior is a
  /// hazard. Ensure any previously set alternate icon is reset to the standard
  /// app identity until a full working calculator decoy is built.
  Future<void> _clearHazardousDisguiseIfSet() async {
    if (widget.settings.disguise != AppDisguise.none) {
      await widget.settings.setDisguise(AppDisguise.none);
      await AppDisguiseChannel.apply(AppDisguise.none);
    }
  }

  @override
  void dispose() {
    if (widget.danger == null) {
      _danger.dispose();
    }
    super.dispose();
  }

  void _unlockPinSession() {
    if (!_pinSessionUnlocked && mounted) {
      setState(() => _pinSessionUnlocked = true);
    }
  }

  void _lockPinSession() {
    if (_pinSessionUnlocked && mounted) {
      setState(() => _pinSessionUnlocked = false);
    }
  }

  void _notifySettingsChanged() {
    if (mounted) {
      setState(() => _settingsRevision++);
    }
  }

  void _registerWipe(VoidCallback cb) => _wipeCallbacks.add(cb);
  void _unregisterWipe(VoidCallback cb) => _wipeCallbacks.remove(cb);

  /// Quick Exit:
  /// 1. Wipes all in-memory form state across active screens.
  /// 2. Locks the PIN session so saved history cannot be viewed.
  /// 3. Pops navigation stack back to the root screen.
  /// 4. Exits straight to the device Home Screen (and removes the Android task
  ///    from Recents via `finishAndRemoveTask()`) without opening `google.com`,
  ///    so no entry is left in her browser history.
  Future<void> _triggerQuickExit() async {
    HapticFeedback.lightImpact();
    for (final cb in List<VoidCallback>.from(_wipeCallbacks)) {
      try {
        cb();
      } catch (_) {}
    }
    _lockPinSession();
    _navKey.currentState?.popUntil((route) => route.isFirst);
    if (KasatConfig.quickExitOpensBrowser) {
      try {
        await launchUrl(
          Uri.parse(KasatConfig.quickExitUrl),
          mode: LaunchMode.externalApplication,
        );
      } catch (_) {}
    }
    try {
      await _privacyChannel.invokeMethod<void>('quickExitToHome');
    } catch (_) {}
    try {
      await SystemNavigator.pop();
    } catch (_) {}
  }

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
      danger: _danger,
      isPinSessionUnlocked: _pinSessionUnlocked,
      settingsRevision: _settingsRevision,
      unlockPinSession: _unlockPinSession,
      lockPinSession: _lockPinSession,
      notifySettingsChanged: _notifySettingsChanged,
      registerWipeCallback: _registerWipe,
      unregisterWipeCallback: _unregisterWipe,
      triggerQuickExit: _triggerQuickExit,
      child: ListenableBuilder(
        listenable: widget.i18n,
        builder: (context, _) => MaterialApp(
          title: 'Kasat',
          navigatorKey: _navKey,
          debugShowCheckedModeBanner: false,
          theme: KasatTheme.build(),
          home: RootGate(
            settings: widget.settings,
            onLockSession: _lockPinSession,
          ),
          builder: (context, child) {
            final media = MediaQuery.of(context);
            return ShakeListener(
              // Safety fix C: shake-to-SMS is gated off by default because
              // vehicle/pocket motion can false-fire an SMS.
              enabled: KasatConfig.enableShakeToSms && widget.duress.hasContact,
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
                child: Column(
                  children: [
                    PersistentSafetyBar(
                      onDangerPressed: () {
                        final navContext = _navKey.currentContext;
                        if (navContext != null) {
                          DangerCountdownSheet.show(navContext);
                        }
                      },
                      onQuickExitPressed: _triggerQuickExit,
                    ),
                    Expanded(child: child!),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class RootGate extends StatefulWidget {
  const RootGate({
    super.key,
    required this.settings,
    this.onLockSession,
  });

  final SettingsStore settings;
  final VoidCallback? onLockSession;

  @override
  State<RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<RootGate> with WidgetsBindingObserver {
  bool _obscured = false;
  bool _online = true;
  StreamSubscription<bool>? _netSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
        widget.onLockSession?.call();
        setState(() {
          _obscured = true;
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
    if (_obscured) return const _PrivacyCover();

    // Zero-setup launch: opens directly with no login or onboarding wall.
    // PIN protection is enforced when saving or viewing saved history/codes.
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
