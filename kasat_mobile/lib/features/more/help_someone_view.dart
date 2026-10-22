import 'package:flutter/material.dart';

import '../../theme/kasat_theme.dart';
import '../../widgets/panel.dart';
import 'more_scaffold.dart';

/// For a friend, sister, or colleague — not the person filling a report.
/// Bright Sky and similar tools keep this path separate so helping someone
/// is not confused with speaking for them.
class HelpSomeoneView extends StatelessWidget {
  const HelpSomeoneView({super.key});

  static const _points = <(IconData, String, String)>[
    (
      Icons.hearing_outlined,
      'Believe them',
      'You do not need the whole story. “I believe you” is enough to start.',
    ),
    (
      Icons.pan_tool_outlined,
      'Do not take over',
      'They choose if, when, and how to report. Offering Kasat is a door, '
          'not a requirement.',
    ),
    (
      Icons.lock_outline_rounded,
      'Keep their story theirs',
      'Do not tell other people, even to be helpful. Ask before you mention '
          'them to anyone.',
    ),
    (
      Icons.favorite_outline_rounded,
      'Offer a number, not advice',
      'Hotlines & support connects to EWLA 7711 and other support lines, '
          'not police. Sit with them while they call if they want that. Do '
          'not dial for them unless they ask.',
    ),
    (
      Icons.nightlight_outlined,
      'Stay close if they want you',
      'A meal, a walk, or sitting nearby can matter more than solving it. '
          'Check in later, once, without pressing.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return MoreScaffold(
      title: 'If you are helping someone',
      children: [
        Text(
          'This page is for you — not for the person who was hurt. Nothing '
          'you do here is sent anywhere.',
          style: KType.sans(size: 15, color: KC.muted, height: 1.55),
        ),
        const SizedBox(height: KSpace.xl),
        KPanel(
          padding: const EdgeInsets.fromLTRB(
            KSpace.lg,
            KSpace.sm,
            KSpace.lg,
            KSpace.lg,
          ),
          child: Column(
            children: [
              for (final (icon, title, body) in _points)
                Padding(
                  padding: const EdgeInsets.only(top: KSpace.lg),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: KC.secondarySoft,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, size: 18, color: KC.secondary),
                      ),
                      const SizedBox(width: KSpace.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: KType.sans(
                                size: 14.5,
                                weight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              body,
                              style: KType.sans(
                                size: 13,
                                color: KC.muted,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: KSpace.lg),
        const KNote(
          title: 'If they are in danger now',
          icon: Icons.info_outline_rounded,
          body:
              'Use a number they already know, or the Help tab. This app '
              'cannot call emergency services for them.',
        ),
      ],
    );
  }
}
