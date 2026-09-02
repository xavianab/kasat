import 'dart:math';

/// Alert identifiers. Deliberately a different prefix from [TrackingId]
/// so a community post can never be mistaken for, or joined to, a report.
abstract final class AlertId {
  static const prefix = 'ALT';
  static const alphabet = '23456789ABCDEFGHJKMNPQRSTVWXYZ';
  static const bodyLength = 5;
  static final _random = Random.secure();

  static String generate() {
    final body = List.generate(
      bodyLength,
      (_) => alphabet[_random.nextInt(alphabet.length)],
    ).join();
    return '$prefix-$body';
  }

  static bool isValid(String input) =>
      RegExp('^$prefix-[$alphabet]{$bodyLength}\$').hasMatch(input);
}
