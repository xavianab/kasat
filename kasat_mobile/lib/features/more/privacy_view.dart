import 'package:flutter/material.dart';

import '../../theme/kasat_theme.dart';
import '../../widgets/panel.dart';
import 'more_scaffold.dart';

/// Plain-language inventory of what lives where.
class PrivacyView extends StatelessWidget {
  const PrivacyView({super.key});

  static const _stays = <(String, String)>[
    (
      'Your code',
      'The six-digit lock stays on this phone as a hash, not as the digits '
          'themselves.',
    ),
    (
      'Your country',
      'Stored here so help lines and the report queue know which place to use. '
          'You can change it in Settings.',
    ),
    (
      'Your safety plan',
      'If you write one, it never leaves this phone and is never attached to '
          'a report.',
    ),
    (
      'Photos you attach',
      'Location and camera details are removed on this phone before anything '
          'is stored.',
    ),
  ];

  static const _never = <(String, String)>[
    (
      'No account',
      'There is no email, no profile, and no list of who uses Kasat.',
    ),
    (
      'No name or number',
      'A report does not ask who you are. Officers cannot call this phone '
          'unless you share your contact details.',
    ),
    (
      'Quiet notifications',
      'If this phone shows an update, the words are only "You have an '
          'update." Nothing about the case appears on the lock screen.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return MoreScaffold(
      title: 'What stays on this phone',
      children: [
        Text(
          'This is what stays on your phone and what is never collected.',
          style: KType.sans(size: 14, color: KC.muted, height: 1.5),
        ),
        const SizedBox(height: KSpace.lg),
        Text(
          'Kept on this phone',
          style: KType.sans(size: 16, weight: FontWeight.w600),
        ),
        for (final (title, body) in _stays) _Fact(title: title, body: body),
        const KRule(height: KSpace.xl),
        Text(
          'Never collected',
          style: KType.sans(size: 16, weight: FontWeight.w600),
        ),
        for (final (title, body) in _never) _Fact(title: title, body: body),
        const SizedBox(height: KSpace.lg),
        const KNote(
          title: 'The honest limit',
          icon: Icons.info_outline_rounded,
          body:
              'If someone else can unlock this phone, they can open Kasat. '
              'Your lock code protects your saved history.',
        ),
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: KSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: KType.sans(size: 14.5, weight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            body,
            style: KType.sans(size: 13, color: KC.muted, height: 1.45),
          ),
        ],
      ),
    );
  }
}
