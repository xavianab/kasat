import 'package:flutter/foundation.dart';

/// Build-time switches for the MVP.
abstract final class KasatConfig {
  static const appName = 'KASAT';
  static const tagline = 'Speak without fear.';
  static const buildChannel = 'MVP-0.1.0';

  /// The mobile client currently persists to an on-device store so the
  /// submission flow can be exercised without a backend. Flip this once
  /// [supabaseUrl]/[supabaseAnonKey] are populated and swap the repository
  /// binding in `main.dart`.
  static const useSupabase = bool.fromEnvironment('KASAT_USE_SUPABASE');
  static const supabaseUrl = String.fromEnvironment('KASAT_SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('KASAT_SUPABASE_ANON_KEY');

  /// Never push a status change to her lock screen. Someone else might see it.
  /// She learns of police updates only by looking up her tracking code.
  static const survivorStatusPush = false;

  /// Walks a sent case forward on a timer only when there is no live portal.
  static const demoDispatch = bool.fromEnvironment('KASAT_DEMO_DISPATCH');
  static const demoTriageDelay = Duration(seconds: 20);

  /// DEMO-ONLY SURVIVOR LOCATION OVERRIDE:
  /// When enabled via `--dart-define=KASAT_DEMO_LOCATION_OVERRIDE=true` (or
  /// `--dart-define=KASAT_DEMO_DISPATCH=true`), the survivor app uses the
  /// configurable Addis Ababa coordinate below (`KASAT_DEMO_SURVIVOR_LAT`,
  /// `KASAT_DEMO_SURVIVOR_LNG`, default Bole `8.9950, 38.7890`) instead of the
  /// device/simulator GPS (which on iOS Simulator defaults to San Francisco).
  ///
  /// PRODUCTION SAFETY INVARIANT:
  /// Guarded by `!kReleaseMode` so this override can NEVER be active in a
  /// real production release binary even if a build script passes the flag.
  static const _rawDemoLocationOverride = bool.fromEnvironment(
    'KASAT_DEMO_LOCATION_OVERRIDE',
    defaultValue: false,
  );
  static bool get isDemoLocationActive =>
      !kReleaseMode && (_rawDemoLocationOverride || demoDispatch);

  static const _demoLatRaw = String.fromEnvironment(
    'KASAT_DEMO_SURVIVOR_LAT',
    defaultValue: '8.9950',
  );
  static const _demoLngRaw = String.fromEnvironment(
    'KASAT_DEMO_SURVIVOR_LNG',
    defaultValue: '38.7890',
  );
  static double get demoSurvivorLatitude =>
      double.tryParse(_demoLatRaw) ?? 8.9950;
  static double get demoSurvivorLongitude =>
      double.tryParse(_demoLngRaw) ?? 38.7890;
  static const demoSurvivorLandmark = String.fromEnvironment(
    'KASAT_DEMO_SURVIVOR_LANDMARK',
    defaultValue: 'Bole — Near Bole Medhanealem & Edna Mall',
  );

  /// Longest edge, in pixels, that an attached image is downscaled to before
  /// it is stored. Doubles as a crude anti-fingerprinting measure.
  static const attachmentMaxEdge = 1280;
  static const maxAttachments = 5;
  static const descriptionMaxLength = 2000;
  static const descriptionMinLength = 40;

  /// Anthropic is never called from the handset. Vent and alert review go
  /// through the `ai-proxy` Edge Function so the API key never ships in the
  /// binary and the survivor's IP is not sent to a third party.
  static const anthropicApiKey = '';
  static const anthropicModel = 'claude-sonnet-4-6';

  /// PART 2: real source verification. True here so the compose path can be
  /// exercised; it does not mean the poster has been identified.
  static const placeholderVerifiedPoster = true;

  static const alertTtl = Duration(days: 14);
  static const alertTitleMax = 80;
  static const alertBodyMax = 600;

  static const ventBodyMax = 1000;
  static const ventTtl = Duration(days: 7);
  static const ventCompanionDelay = Duration(seconds: 4);

  static const duressCountdown = Duration(seconds: 20);

  /// Gate off shake-to-SMS by default: accelerometer shake detection can
  /// false-fire in vehicles, minibuses, and pockets, risking an accidental SMS.
  static const enableShakeToSms =
      bool.fromEnvironment('KASAT_ENABLE_SHAKE_SMS', defaultValue: false);

  /// Configurable regional emergency number for the "I'm in Danger" button.
  ///
  /// ETHIOPIA PLACEHOLDER (VERIFY BEFORE PRODUCTION RELEASE):
  /// - `991`: Addis Ababa Police Commission / Ethiopian Federal Police toll-free
  ///   emergency dispatch shortcode.
  /// - `7711`: Ethiopian Women Lawyers Association (EWLA) toll-free GBV hotline
  ///   (listed separately in the Help / Resources screen).
  ///
  /// Override per region at build time via:
  ///   `--dart-define=KASAT_EMERGENCY_NUMBER=991`
  ///
  /// PLATFORM LEGAL MINIMUM NOTE:
  /// Both iOS (tel:// confirmation sheet) and Android (Intent.ACTION_DIAL for
  /// emergency shortcodes) prohibit third-party apps from placing zero-tap
  /// automatic emergency calls. Pre-filling the system dialer so she taps once
  /// to connect is the strict legal and technical minimum on both platforms.
  static const emergencyNumber =
      String.fromEnvironment('KASAT_EMERGENCY_NUMBER', defaultValue: '991');

  /// EWLA (Ethiopian Women Lawyers Association) toll-free national GBV hotline.
  static const ewlaGbvHotline =
      String.fromEnvironment('KASAT_EWLA_HOTLINE', defaultValue: '7711');

  /// Countdown before the "I'm in Danger" button fires phone + portal alerts.
  static const dangerCountdown = Duration(seconds: 5);

  /// Configurable window for streaming live GPS coordinates to the police
  /// portal during an active "I'm in Danger" escalation (default: 30 minutes).
  static const dangerLiveLocationMinutes = int.fromEnvironment(
    'KASAT_DANGER_LOCATION_MINUTES',
    defaultValue: 30,
  );
  static const dangerLiveLocationWindow =
      Duration(minutes: dangerLiveLocationMinutes);

  /// Neutral, non-identifying Android foreground service notification strings
  /// used during the 30-minute live location stream so an abuser standing next
  /// to her sees no app name, no mention of location/GPS, and no emergency text.
  static const foregroundNotificationTitle = 'System service running';
  static const foregroundNotificationBody = 'Background sync is active';
  static const foregroundNotificationChannel = 'System Sync';
  static const foregroundNotificationIcon = 'ic_stat_sync';

  /// By default Quick Exit returns straight to the OS Home Screen (and removes
  /// the task from Android Recents) rather than opening a browser URL, so no
  /// timestamped `google.com` entry is left in her browser history.
  static const quickExitOpensBrowser = bool.fromEnvironment(
    'KASAT_QUICK_EXIT_OPENS_BROWSER',
    defaultValue: false,
  );
  static const quickExitUrl = String.fromEnvironment(
    'KASAT_QUICK_EXIT_URL',
    defaultValue: 'https://www.google.com',
  );
}
