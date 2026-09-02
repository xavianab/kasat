import 'package:flutter/material.dart';

import '../../theme/kasat_theme.dart';
import '../../widgets/panel.dart';
import 'more_scaffold.dart';

/// Plain-language inventory of what lives where. People will not report if
/// they cannot picture what a seized phone or a curious operator would see.
class PrivacyView extends StatelessWidget {
  const PrivacyView({super.key});

  static const _stays = <(String, String)>[
    (
      'Your code',
      'The six-digit lock stays on this phone as a hash, not as the digits '
          'themselves. Face ID, if you turned it on, is handled by the phone.',
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
      'A report does not ask who you are. Operators cannot ring this phone '
          'from the case.',
    ),
    (
      'Quiet notifications',
      'If this phone ever shows an update, the words are only “You have an '
          'update.” Nothing about the case appears on the lock screen.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return MoreScaffold(
      title: 'What stays on this phone',
      children: [
        Text(
          'You should be able to answer “what would someone see?” without '
          'guessing. This is the honest list for this version of the app.',
          style: KType.sans(size: 15, color: KC.muted, height: 1.55),
        ),
        const SizedBox(height: KSpace.xl),
        KPanel(
          title: 'Kept on this phone',
          padding: const EdgeInsets.fromLTRB(
            KSpace.lg,
            0,
            KSpace.lg,
            KSpace.lg,
          ),
          child: Column(
            children: [
              for (final (title, body) in _stays)
                _Fact(title: title, body: body),
            ],
          ),
        ),
        const SizedBox(height: KSpace.md),
        KPanel(
          title: 'Never collected',
          padding: const EdgeInsets.fromLTRB(
            KSpace.lg,
            0,
            KSpace.lg,
            KSpace.lg,
          ),
          child: Column(
            children: [
              for (final (title, body) in _never)
                _Fact(title: title, body: body),
            ],
          ),
        ),
        const SizedBox(height: KSpace.lg),
        const KNote(
          title: 'The honest limit',
          icon: Icons.info_outline_rounded,
          body:
              'This phone still belongs to the maker and the store. If '
              'someone else can unlock it, they can open Kasat and see what '
              'is on it. The lock code is the main door.',
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
      padding: const EdgeInsets.only(top: KSpace.lg),
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
