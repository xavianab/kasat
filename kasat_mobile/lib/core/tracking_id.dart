import 'dart:math';

/// Client-side tracking identifiers.
///
/// The identifier is minted on the handset and is the *only* link between a
/// survivor and their report. The server never sees a user account, so if this
/// code is lost the case cannot be re-associated — that is the intended
/// trade-off, and the UI says so plainly.
abstract final class TrackingId {
  static const prefix = 'KST';

  /// Crockford-style alphabet with 0/O/1/I/L/U removed so a code read aloud,
  /// written on paper, or typed from memory cannot round-trip into a
  /// different valid code.
  static const alphabet = '23456789ABCDEFGHJKMNPQRSTVWXYZ';
  static const bodyLength = 5;

  static final _random = Random.secure();
  static final _pattern = RegExp('^$prefix-[$alphabet]{$bodyLength}\$');

  /// Mints a new identifier, e.g. `KST-8X9P2`.
  static String generate() {
    final body = List.generate(
      bodyLength,
      (_) => alphabet[_random.nextInt(alphabet.length)],
    ).join();
    return '$prefix-$body';
  }

  /// Accepts what a human actually types — `kst 8x9p2`, `KST8X9P2`, `8x9p2`,
  /// stray whitespace — and returns the canonical form, or null if it could
  /// never be a Kasat code.
  static String? normalize(String input) {
    var cleaned = input.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');
    if (cleaned.startsWith(prefix)) {
      cleaned = cleaned.substring(prefix.length);
    }
    if (cleaned.length != bodyLength) return null;
    if (cleaned.split('').any((c) => !alphabet.contains(c))) return null;
    return '$prefix-$cleaned';
  }

  static bool isValid(String input) => _pattern.hasMatch(input);
}
