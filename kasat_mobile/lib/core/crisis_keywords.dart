/// On-device crisis phrases. Update this list without touching detection logic.
///
/// Kept short and unambiguous. Broad words like "hurt" or "scared" match
/// almost every report and would make the banner meaningless.
///
/// This file is never sent anywhere. Detection reads it locally only.
const crisisKeywords = <String>[
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
  'want to die',
  'end my life',
  'suicide',
];
