import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/kasat_config.dart';
import '../../core/network_status.dart';
import '../../core/tracking_id.dart';
import '../../data/incident_repository.dart';
import '../../data/settings_store.dart';
import '../../models/incident.dart';

/// Coordinates the "I'm in Danger" automatic escalation and its 30-minute
/// live-location beacon.
///
/// IMPORTANT — LIVE LOCATION BOUNDARY:
/// Live GPS (`Geolocator`) is ONLY invoked here during an explicit "I'm in
/// Danger" activation. The standard report flow (`ReportFormView`) never
/// requests or transmits GPS coordinates.
class DangerController extends ChangeNotifier {
  DangerController({
    required this.repository,
    required this.settings,
    required this.network,
  });

  final IncidentRepository repository;
  final SettingsStore settings;
  final NetworkStatus network;

  String? _activeTrackingId;
  DateTime? _expiresAt;
  bool _silentMode = false;
  double? _lastLatitude;
  double? _lastLongitude;
  double? _lastAccuracyMeters;
  DateTime? _officerArrivedAtUtc;
  int _approachResponseWindowSec = 90;
  String? _approachResponse;
  bool _hasVibratedForArrival = false;
  int _arrivalVibrationCount = 0;
  Timer? _windowTimer;
  Timer? _pollTimer;
  Timer? _arrivalPollTimer;
  StreamSubscription<Position>? _positionSub;

  bool get isLiveLocationActive =>
      _activeTrackingId != null &&
      _expiresAt != null &&
      DateTime.now().isBefore(_expiresAt!);

  String? get activeTrackingId => _activeTrackingId;
  DateTime? get expiresAt => _expiresAt;
  bool get silentMode => _silentMode;
  double? get lastLatitude => _lastLatitude;
  double? get lastLongitude => _lastLongitude;
  double? get lastAccuracyMeters => _lastAccuracyMeters;
  DateTime? get officerArrivedAtUtc => _officerArrivedAtUtc;
  int get approachResponseWindowSec => _approachResponseWindowSec;
  String? get approachResponse => _approachResponse;
  bool get hasOfficerArrived => _officerArrivedAtUtc != null;
  int get arrivalVibrationCount => _arrivalVibrationCount;

  Duration get remainingWindow {
    if (_expiresAt == null) return Duration.zero;
    final diff = _expiresAt!.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  /// Builds platform-specific location settings for the 30-minute emergency
  /// stream.
  ///
  /// ANDROID FOREGROUND NOTIFICATION SAFETY:
  /// Android requires a foreground notification when streaming location in the
  /// background. To prevent an abuser standing next to her from seeing "Kasat"
  /// or "location", we configure:
  /// - Title: `System service running`
  /// - Body: `Background sync is active`
  /// - Channel: `System Sync` (importance `IMPORTANCE_NONE` / `VISIBILITY_PRIVATE`)
  /// - Small Icon: `@drawable/ic_stat_sync` (neutral monochrome sync icon)
  /// - App header label: `System Service` (via `<application android:label>` in
  ///   `AndroidManifest.xml`, while `MainActivity` retains `android:label="Kasat"`).
  ///
  /// iOS BACKGROUND LOCATION INDICATOR:
  /// Sets `allowBackgroundLocationUpdates: true` and
  /// `showBackgroundLocationIndicator: false` (note: iOS CoreLocation still
  /// displays a blue arrow pill in the status bar / Dynamic Island when
  /// permission is `WhenInUse`, which shows no text in the status bar itself).
  static LocationSettings buildStreamLocationSettings({
    TargetPlatform? platformOverride,
  }) {
    final platform = platformOverride ?? defaultTargetPlatform;
    if (platform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
        intervalDuration: const Duration(seconds: 15),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: KasatConfig.foregroundNotificationTitle,
          notificationText: KasatConfig.foregroundNotificationBody,
          notificationChannelName: KasatConfig.foregroundNotificationChannel,
          notificationIcon: AndroidResource(
            name: KasatConfig.foregroundNotificationIcon,
            defType: 'drawable',
          ),
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    }
    if (platform == TargetPlatform.iOS || platform == TargetPlatform.macOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
        pauseLocationUpdatesAutomatically: false,
        allowBackgroundLocationUpdates: true,
        showBackgroundLocationIndicator: false,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );
  }

  /// Fired when the 5-second countdown completes without cancellation.
  ///
  /// Runs two actions in parallel:
  /// 1. PHONE: Opens the system dialer pre-filled with the regional emergency
  ///    number (`KasatConfig.emergencyNumber`, configurable per region, never
  ///    hardcoded) unless [silent] is true.
  /// 2. PORTAL: Writes an URGENT-priority (`CRTCL` / `P1`, `is_emergency=true`)
  ///    row to Supabase with live GPS coordinates, timestamp, and emergency
  ///    flag, and starts the 30-minute live location stream.
  Future<Incident> escalateNow({bool silent = false}) async {
    // Coalesce repeat activations on the same handset while a danger window is
    // already active so panic-tapping never spawns duplicate alerts.
    if (isLiveLocationActive && _activeTrackingId != null) {
      final existingId = _activeTrackingId!;
      _silentMode = _silentMode || silent;
      if (!silent) {
        unawaited(_openEmergencyDialer());
      }
      final pos = await _tryReadPosition();
      if (pos != null) {
        _lastLatitude = pos.latitude;
        _lastLongitude = pos.longitude;
        _lastAccuracyMeters = pos.accuracy;
        await repository.updateEmergencyLocation(
          existingId,
          latitude: pos.latitude,
          longitude: pos.longitude,
          accuracyMeters: pos.accuracy,
        );
      }
      final current = await repository.lookup(existingId);
      notifyListeners();
      if (current != null) return current;
    }

    _silentMode = silent;
    _officerArrivedAtUtc = null;
    _approachResponse = null;
    _hasVibratedForArrival = false;
    final trackingId = TrackingId.generate();
    final countryCode = settings.effectiveCountryCode;

    // Fire phone dialer and portal dispatch in parallel.
    final results = await Future.wait<dynamic>([
      if (!silent) _openEmergencyDialer() else Future<void>.value(),
      _dispatchEmergencyReport(
        trackingId: trackingId,
        countryCode: countryCode,
        silentMode: silent,
      ),
    ]);

    final incident = results.last as Incident;
    _startLiveLocationWindow(incident.trackingId);
    return incident;
  }

  /// Opens the platform phone dialer pre-filled with the configured emergency
  /// number (`KasatConfig.emergencyNumber`).
  ///
  /// PLATFORM LEGAL & TECHNICAL NOTE:
  /// Both iOS and Android prohibit third-party apps from placing zero-tap
  /// automatic emergency calls:
  /// - On iOS, `tel://` always presents a native confirmation alert, and
  ///   CallKit (`CXStartCallAction`) explicitly blocks third-party VoIP apps
  ///   from initiating PSTN emergency calls.
  /// - On Android, `Intent.ACTION_CALL` explicitly prohibits emergency
  ///   shortcodes (`991`, `911`, `112`) for any app that is not the user's
  ///   system-selected default Phone dialer (`RoleManager.ROLE_DIALER`).
  /// Pre-filling the system dialer via `tel:` so she taps once to connect is
  /// the strict legal and technical minimum on both platforms.
  Future<void> _openEmergencyDialer() async {
    final rawNumber = KasatConfig.emergencyNumber;
    final dialable = rawNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    if (dialable.isEmpty) return;
    try {
      await launchUrl(
        Uri(scheme: 'tel', path: dialable),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      // Simulator or call-less tablet: copy number to clipboard so it is ready.
      await Clipboard.setData(ClipboardData(text: dialable));
    }
  }

  Future<Incident> _dispatchEmergencyReport({
    required String trackingId,
    required String countryCode,
    required bool silentMode,
  }) async {
    final pos = await _tryReadPosition();
    _lastLatitude = pos?.latitude;
    _lastLongitude = pos?.longitude;
    _lastAccuracyMeters = pos?.accuracy;

    final offline = !await network.isOnline();
    return repository.triggerEmergency(
      trackingId: trackingId,
      countryCode: countryCode,
      latitude: _lastLatitude,
      longitude: _lastLongitude,
      accuracyMeters: _lastAccuracyMeters,
      silentMode: silentMode,
      offline: offline,
    );
  }

  void _startLiveLocationWindow(String trackingId) {
    _cancelTimers();
    _activeTrackingId = trackingId;
    _expiresAt = DateTime.now().add(KasatConfig.dangerLiveLocationWindow);
    notifyListeners();

    _windowTimer = Timer(KasatConfig.dangerLiveLocationWindow, () {
      stopLiveLocation();
    });

    // Listen for continuous position updates during the danger window.
    _subscribePositionStream(trackingId);

    // Poll every 4 seconds for officer arrival ("I have arrived") so her phone
    // vibrates ONCE silently and shows the approach confirmation buttons when open.
    _arrivalPollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      checkOfficerArrivalNow();
    });

    // Periodic fallback tick every 15 seconds while the window is active.
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      if (!isLiveLocationActive) {
        await stopLiveLocation();
        return;
      }
      final pos = await _tryReadPosition();
      if (pos != null) {
        _lastLatitude = pos.latitude;
        _lastLongitude = pos.longitude;
        _lastAccuracyMeters = pos.accuracy;
        notifyListeners();
        await repository.updateEmergencyLocation(
          trackingId,
          latitude: pos.latitude,
          longitude: pos.longitude,
          accuracyMeters: pos.accuracy,
        );
      }
    });
  }

  /// Checks whether the responding officer tapped "I have arrived" on the
  /// portal.
  ///
  /// SAFETY INVARIANT (Requirements 2 & 5):
  /// - Vibrates ONCE (`HapticFeedback.vibrate()`) and ONLY ONCE per arrival.
  /// - NEVER plays any audio tone, sound, or alert.
  /// - NEVER posts a notification or wakes/changes the lock screen.
  Future<void> checkOfficerArrivalNow() async {
    final id = _activeTrackingId;
    if (id == null || !isLiveLocationActive) return;
    final latest = await repository.lookup(id);
    if (latest == null || _activeTrackingId != id) return;

    final arrivedAt = latest.officerArrivedAtUtc;
    var changed = false;

    if (arrivedAt != null && _officerArrivedAtUtc != arrivedAt) {
      final isFirstNotice =
          !_hasVibratedForArrival || _officerArrivedAtUtc != arrivedAt;
      _officerArrivedAtUtc = arrivedAt;
      _approachResponseWindowSec = latest.approachResponseWindowSec;
      changed = true;
      if (isFirstNotice) {
        _hasVibratedForArrival = true;
        _arrivalVibrationCount++;
        await HapticFeedback.vibrate();
      }
    }

    if (latest.approachResponse != _approachResponse) {
      _approachResponse = latest.approachResponse;
      changed = true;
    }

    if (changed) {
      notifyListeners();
    }
  }

  /// Submits the survivor's silent approach confirmation:
  /// - `'can_come_out'` ("I can come out")
  /// - `'abuser_present_do_not_knock'` ("He is here — do not knock")
  Future<void> respondToOfficerApproach(String response) async {
    final id = _activeTrackingId;
    if (id == null) return;
    _approachResponse = response;
    notifyListeners();
    await repository.submitApproachResponse(id, response: response);
  }

  /// DEMO-ONLY SURVIVOR LOCATION OVERRIDE:
  /// Returns the configured Addis Ababa coordinate (`KasatConfig.demoSurvivorLatitude`,
  /// `KasatConfig.demoSurvivorLongitude`, default Bole `8.9950, 38.7890`).
  /// Guarded by `KasatConfig.isDemoLocationActive` (`!kReleaseMode && ...`) so
  /// this is NEVER active in a real production release build.
  static Position _buildDemoOverridePosition() {
    assert(
      !kReleaseMode,
      'Demo location override must never run in a release build.',
    );
    return Position(
      latitude: KasatConfig.demoSurvivorLatitude,
      longitude: KasatConfig.demoSurvivorLongitude,
      timestamp: DateTime.now(),
      accuracy: 9.5,
      altitude: 2355,
      altitudeAccuracy: 10,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  }

  Future<void> _subscribePositionStream(String trackingId) async {
    // In demo mode (non-release only), keep the configured Addis Ababa demo
    // coordinate instead of subscribing to the iOS Simulator's San Francisco GPS.
    if (KasatConfig.isDemoLocationActive) {
      return;
    }
    try {
      final hasPerm = await _ensureLocationPermission();
      if (!hasPerm) return;
      _positionSub = Geolocator.getPositionStream(
        locationSettings: buildStreamLocationSettings(),
      ).listen((pos) {
        if (!isLiveLocationActive || _activeTrackingId != trackingId) return;
        _lastLatitude = pos.latitude;
        _lastLongitude = pos.longitude;
        _lastAccuracyMeters = pos.accuracy;
        notifyListeners();
        repository.updateEmergencyLocation(
          trackingId,
          latitude: pos.latitude,
          longitude: pos.longitude,
          accuracyMeters: pos.accuracy,
        );
      });
    } catch (_) {
      // Fallback to _pollTimer if position stream is unsupported.
    }
  }

  /// Stops live location streaming immediately and writes `emergency_stopped`
  /// to `report_audit_log`.
  Future<void> stopLiveLocation() async {
    final id = _activeTrackingId;
    _cancelTimers();
    _activeTrackingId = null;
    _expiresAt = null;
    _silentMode = false;
    _officerArrivedAtUtc = null;
    _approachResponse = null;
    _hasVibratedForArrival = false;
    notifyListeners();
    if (id != null) {
      await repository.stopEmergencyLocation(id);
    }
  }

  Future<Position?> _tryReadPosition() async {
    if (KasatConfig.isDemoLocationActive) {
      return _buildDemoOverridePosition();
    }
    try {
      final ok = await _ensureLocationPermission();
      if (!ok) return null;
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 4),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  Future<bool> _ensureLocationPermission() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return false;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      return perm == LocationPermission.always ||
          perm == LocationPermission.whileInUse;
    } catch (_) {
      return false;
    }
  }

  void _cancelTimers() {
    _windowTimer?.cancel();
    _windowTimer = null;
    _pollTimer?.cancel();
    _pollTimer = null;
    _arrivalPollTimer?.cancel();
    _arrivalPollTimer = null;
    _positionSub?.cancel();
    _positionSub = null;
  }

  @override
  void dispose() {
    _cancelTimers();
    super.dispose();
  }
}
