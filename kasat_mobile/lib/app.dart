import 'package:flutter/material.dart';

import 'core/quick_exit.dart';
import 'data/attachment_store.dart';
import 'data/incident_repository.dart';
import 'data/settings_store.dart';
import 'features/decoy/notes_decoy_view.dart';
import 'features/lock/lock_screen.dart';
import 'features/onboarding/onboarding_flow.dart';
import 'features/welcome/welcome_view.dart';
import 'theme/kasat_theme.dart';
import 'widgets/quick_exit_button.dart';

/// Dependency handoff. Deliberately a plain InheritedWidget — there are four
/// dependencies and a DI container would be more moving parts than the app has
/// state.
class KasatScope extends InheritedWidget {
  const KasatScope({
    super.key,
    required this.repository,
    required this.attachments,
    required this.settings,
    required this.quickExit,
    required super.child,
  });

  final IncidentRepository repository;
  final AttachmentStore attachments;
  final SettingsStore settings;
  final QuickExitController quickExit;

  static KasatScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<KasatScope>();
    assert(scope != null, 'KasatScope is missing above this widget.');
    return scope!;
  }

  @override
  bool updateShouldNotify(KasatScope oldWidget) =>
      repository != oldWidget.repository ||
      attachments != oldWidget.attachments ||
      settings != oldWidget.settings;
}

class KasatApp extends StatefulWidget {
  const KasatApp({
    super.key,
    required this.repository,
    required this.attachments,
    required this.settings,
  });

  final IncidentRepository repository;
  final AttachmentStore attachments;
  final SettingsStore settings;

  @override
  State<KasatApp> createState() => _KasatAppState();
}

class _KasatAppState extends State<KasatApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  late final QuickExitController _quickExit = QuickExitController(_navigatorKey);

  @override
  void dispose() {
    _quickExit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KasatScope(
      repository: widget.repository,
      attachments: widget.attachments,
      settings: widget.settings,
      quickExit: _quickExit,
      child: MaterialApp(
        // Shown in the iOS app switcher, so it must not name the app.
        title: 'Notes',
        navigatorKey: _navigatorKey,
        debugShowCheckedModeBanner: false,
        theme: KasatTheme.build(),
        home: RootGate(settings: widget.settings, quickExit: _quickExit),
        builder: (context, child) {
          final media = MediaQuery.of(context);
          return MediaQuery(
            // Clamp text scaling: the layouts stay readable across this range,
            // and a 2x system scale would push the quick-exit button off-screen.
            data: media.copyWith(
              textScaler: TextScaler.linear(
                media.textScaler.scale(1).clamp(0.9, 1.3),
              ),
            ),
            child: Stack(
              children: [
                child!,
                // Lives above the Navigator so it survives navigation and sits
                // on top of sheets and dialogs.
                QuickExitButton(controller: _quickExit),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Decides what the app shows before anything else runs: setup, the lock
/// screen, the decoy, or Kasat itself.
class RootGate extends StatefulWidget {
  const RootGate({super.key, required this.settings, required this.quickExit});

  final SettingsStore settings;
  final QuickExitController quickExit;

  @override
  State<RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<RootGate> with WidgetsBindingObserver {
  bool _onboarded = false;
  bool _locked = true;

  /// True while the app is leaving the foreground. iOS snapshots the window for
  /// the app switcher at that moment, so the real screen has to be covered
  /// before it happens — not after `resumed`, which is too late.
  bool _obscured = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _onboarded = widget.settings.onboardingComplete;
    widget.quickExit.decoyActive.addListener(_onDecoyChanged);
    _syncQuickExitVisibility();
  }

  @override
  void dispose() {
    widget.quickExit.decoyActive.removeListener(_onDecoyChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onDecoyChanged() {
    setState(_syncQuickExitVisibility);
  }

  void _syncQuickExitVisibility() {
    // No exit button during setup, on the lock screen, or on the decoy.
    widget.quickExit.visible.value =
        _onboarded && !_locked && !widget.quickExit.decoyActive.value;
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
          _syncQuickExitVisibility();
        });
      case AppLifecycleState.resumed:
        setState(() => _obscured = false);
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
          _syncQuickExitVisibility();
        }),
      );
    }

    if (widget.quickExit.decoyActive.value) {
      return NotesDecoyView(
        onSecretUnlock: () => setState(() {
          // Returning from the decoy always costs a PIN. Anything less and the
          // exit button would be a one-way door that anyone can walk back
          // through.
          _locked = true;
          widget.quickExit.leaveDecoy();
          _syncQuickExitVisibility();
        }),
      );
    }

    if (_locked) {
      return LockScreen(
        settings: widget.settings,
        onUnlocked: () => setState(() {
          _locked = false;
          _obscured = false;
          _syncQuickExitVisibility();
        }),
      );
    }

    if (_obscured) return const _PrivacyCover();

    return const WelcomeView();
  }
}

/// Plain warm panel shown over the app as it leaves the foreground.
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
