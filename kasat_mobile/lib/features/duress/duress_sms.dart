import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import 'duress_store.dart';

/// Hands a pre-filled SMS to the system composer.
///
/// iOS will not send an SMS with no UI. Android can, with SEND_SMS, which we
/// do not request in this MVP — the composer is the honest, demoable path on
/// both platforms. Cell signal is enough; no data connection is required for
/// the message itself once the composer is up.
Future<bool> offerDuressSms(TrustedContact contact) async {
  var maps = '';
  try {
    final permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse) {
      final pos = await Geolocator.getLastKnownPosition() ??
          await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: Duration(seconds: 8),
            ),
          );
      maps =
          'https://maps.google.com/?q=${pos.latitude.toStringAsFixed(5)},${pos.longitude.toStringAsFixed(5)}';
    }
  } catch (_) {
    // Location is best-effort. The SMS still goes without it.
  }

  final body = StringBuffer(
    'This is an automatic alert from Kasat. ${contact.name} may be in danger.',
  );
  if (maps.isNotEmpty) {
    body.write(' Last known location: $maps');
  }

  final uri = Uri(
    scheme: 'sms',
    path: contact.phone,
    queryParameters: {'body': body.toString()},
  );
  return launchUrl(uri);
}
