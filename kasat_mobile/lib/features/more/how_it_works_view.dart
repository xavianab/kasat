import 'package:flutter/material.dart';

import '../../app.dart';
import '../../models/country.dart';
import '../../theme/kasat_theme.dart';
import '../../widgets/panel.dart';
import 'more_scaffold.dart';

/// Process transparency. Survivor-centered guidance asks for this before
/// someone is asked to describe what happened — so they know what they are
/// walking into, and that they can stop.
class HowItWorksView extends StatelessWidget {
  const HowItWorksView({super.key});

  static const _steps = <(String, String)>[
    (
      'You write what happened',
      'No name, no account, no phone number. You choose how much to say, '
          'and you can leave the form at any time.',
    ),
    (
      'This phone makes a code',
      'A code like KST-XXXXX is created here, not by us. Write it down '
          'somewhere only you can find. It is how you check on the case later.',
    ),
    (
      'It goes to your country’s queue',
      'The country you chose at setup tells us which operators see it. They '
          'do not get your number or a way to call you back.',
    ),
    (
      'You can look it up later',
      'Use Check my case and type the code. Status may sit still for a while. '
          'That does not mean nothing is happening — and it does not mean you '
          'did anything wrong.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final country = countryByCode(KasatScope.of(context).settings.countryCode);

    return MoreScaffold(
      title: 'How this works',
      children: [
        Text(
          'You do not have to report anything to use this app. These four '
          'steps are only here so the path is not a surprise.',
          style: KType.sans(size: 15, color: KC.muted, height: 1.55),
        ),
        const SizedBox(height: KSpace.xl),
        for (var i = 0; i < _steps.length; i++) ...[
          KPanel(
            step: i + 1,
            title: _steps[i].$1,
            child: Text(
              _steps[i].$2,
              style: KType.sans(size: 14, color: KC.muted, height: 1.5),
            ),
          ),
          const SizedBox(height: KSpace.md),
        ],
        KNote(
          title: country == null
              ? 'Your country is how a report is routed'
              : 'Reports from ${country.name}',
          icon: Icons.place_outlined,
          body: country == null
              ? 'Choose a country in Settings if you have not already. Help '
                    'lines and the report queue both follow that choice.'
              : 'A report from here is meant for people who handle the '
                    '${country.name} queue. Hotlines & support connects to '
                    'EWLA 7711 and other support lines, not police. If you '
                    'are in danger right now, use a number you already trust.',
        ),
      ],
    );
  }
}
