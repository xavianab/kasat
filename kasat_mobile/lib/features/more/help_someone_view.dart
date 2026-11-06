import 'package:flutter/material.dart';

import '../../theme/kasat_theme.dart';
import '../../widgets/panel.dart';
import 'more_scaffold.dart';

/// Guidance for a friend, sister, or colleague helping someone who was hurt.
class HelpSomeoneView extends StatelessWidget {
  const HelpSomeoneView({super.key});

  static const _points = <(IconData, String, String)>[
    (
      Icons.hearing_outlined,
      'Believe them',
      'You do not need the whole story. Saying "I believe you" is enough to start.',
    ),
    (
      Icons.pan_tool_outlined,
      'Do not take over',
      'They choose if, when, and how to report. Offering Kasat is an option, '
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
          'Check in later without pressing.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return MoreScaffold(
      title: 'If you are helping someone',
      children: [
        Text(
          'This page is for you, not for the person who was hurt. Nothing '
          'you do here is sent anywhere.',
          style: KType.sans(size: 14, color: KC.muted, height: 1.5),
        ),
        const SizedBox(height: KSpace.lg),
        for (var i = 0; i < _points.length; i++) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(_points[i].$1, size: 18, color: KC.primary),
              const SizedBox(width: KSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _points[i].$2,
                      style: KType.sans(size: 14.5, weight: FontWeight.w600),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _points[i].$3,
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
          if (i < _points.length - 1) const KRule(height: KSpace.lg),
        ],
        const SizedBox(height: KSpace.lg),
        const KNote(
          title: 'If they are in danger now',
          icon: Icons.info_outline_rounded,
          body:
              'Use a number they already know, or the Hotlines tab. This app '
              'cannot call emergency services for them.',
        ),
      ],
    );
  }
}
