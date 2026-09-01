import '../models/incident_category.dart';

class CrisisSignal {
  const CrisisSignal({required this.triggered, this.reason});

  const CrisisSignal.none() : triggered = false, reason = null;

  final bool triggered;

  /// Plain-language explanation shown to the survivor, so the banner never
  /// appears for a reason she cannot see.
  final String? reason;
}

/// Decides when to surface immediate help alongside the form.
///
/// This runs entirely on the handset against text that has not been sent
/// anywhere, and it is deliberately crude: it can only ever *add* an offer of
/// help, never block a submission, change a priority, or leave the device. A
/// false positive costs a banner; a false negative costs nothing that the
/// resources tab does not already cover.
abstract final class CrisisDetection {
  /// Phrases that suggest danger is present rather than past. Kept short and
  /// unambiguous — broad words like "hurt" or "scared" match almost every
  /// report and would make the banner meaningless.
  static const dangerPhrases = <String>[
    'right now',
    'still here',
    'still outside',
    'about to',
    'going to kill',
    'threatening to kill',
    'has a gun',
    'has a knife',
    'with a weapon',
    'bleeding',
    'cannot breathe',
    "can't breathe",
    'locked in',
    'trapped',
    'following me',
    'outside my door',
    'kill myself',
  ];

  static CrisisSignal evaluate({
    required IncidentCategory? category,
    required String description,
  }) {
    if (category == IncidentCategory.criticalEmergency) {
      return const CrisisSignal(
        triggered: true,
        reason: 'You marked this as an emergency.',
      );
    }

    final text = description.toLowerCase();
    for (final phrase in dangerPhrases) {
      if (text.contains(phrase)) {
        return const CrisisSignal(
          triggered: true,
          reason: 'What you wrote sounds like it may still be happening.',
        );
      }
    }

    return const CrisisSignal.none();
  }
}
