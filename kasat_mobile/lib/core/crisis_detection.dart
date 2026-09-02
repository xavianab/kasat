import '../models/incident_category.dart';
import 'crisis_keywords.dart';

class CrisisSignal {
  const CrisisSignal({required this.triggered, this.reason});

  const CrisisSignal.none() : triggered = false, reason = null;

  final bool triggered;

  /// Plain-language explanation shown to the survivor, so the banner never
  /// appears for a reason she cannot see.
  final String? reason;
}

/// Decides when to surface immediate help alongside a form or a Vent post.
///
/// This runs entirely on the handset against text that has not been sent
/// anywhere, and it is deliberately crude: it can only ever *add* an offer of
/// help, never block a submission, change a priority, or leave the device. A
/// false positive costs a banner; a false negative costs nothing that the
/// resources tab does not already cover.
///
/// Nothing about a match is logged or transmitted.
abstract final class CrisisDetection {
  static const dangerPhrases = crisisKeywords;

  static CrisisSignal evaluate({
    IncidentCategory? category,
    required String description,
  }) {
    if (category == IncidentCategory.criticalEmergency) {
      return const CrisisSignal(
        triggered: true,
        reason: 'You marked this as an emergency.',
      );
    }
    return evaluateText(description);
  }

  /// Keyword-only check used by Vent Here (no category).
  static CrisisSignal evaluateText(String description) {
    final text = description.toLowerCase();
    for (final phrase in crisisKeywords) {
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
