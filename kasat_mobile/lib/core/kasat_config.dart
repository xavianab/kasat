/// Build-time switches for the MVP.
abstract final class KasatConfig {
  static const appName = 'KASAT';
  static const tagline = 'Speak without fear.';
  static const buildChannel = 'MVP-0.1.0';

  /// The mobile client currently persists to an on-device store so the
  /// submission flow can be exercised without a backend. Flip this once
  /// [supabaseUrl]/[supabaseAnonKey] are populated and swap the repository
  /// binding in `main.dart`.
  static const useSupabase = false;
  static const supabaseUrl = String.fromEnvironment('KASAT_SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('KASAT_SUPABASE_ANON_KEY');

  /// With no operator dashboard attached yet, nothing would ever move a case
  /// off "Received". This walks freshly submitted cases forward on a timer so
  /// the realtime lookup view can be verified end to end. Turn it off the
  /// moment the Next.js dashboard is writing real status updates.
  static const demoDispatch = true;
  static const demoTriageDelay = Duration(seconds: 20);

  /// Longest edge, in pixels, that an attached image is downscaled to before
  /// it is stored. Doubles as a crude anti-fingerprinting measure.
  static const attachmentMaxEdge = 1280;
  static const maxAttachments = 5;
  static const descriptionMaxLength = 2000;
  static const descriptionMinLength = 40;
}
