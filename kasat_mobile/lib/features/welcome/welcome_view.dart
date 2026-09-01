import 'package:flutter/material.dart';

import '../../core/kasat_config.dart';
import '../../theme/kasat_theme.dart';
import '../../widgets/grid_backdrop.dart';
import '../../widgets/kasat_button.dart';
import '../../widgets/mono_badge.dart';
import '../../widgets/panel.dart';
import '../shell/shell_view.dart';

class WelcomeView extends StatelessWidget {
  const WelcomeView({super.key});

  static const _guarantees = <(String, String)>[
    ('No IP logging', 'Requests are relayed without an originating address.'),
    ('Metadata scrubbed', 'EXIF, GPS and device tags stripped on the handset.'),
    ('No account required', 'Nothing to sign in to, so nothing to subpoena.'),
    ('Client-side case ID', 'Your tracking code is minted here, not by us.'),
  ];

  void _open(BuildContext context, ShellTab tab) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ShellView(initialTab: tab)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KC.canvas,
      body: GridBackdrop(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(KSpace.lg, KSpace.md, KSpace.lg, KSpace.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _WordmarkBar(),
                const SizedBox(height: KSpace.xl),
                Text(
                  'SPEAK\nWITHOUT FEAR.',
                  style: KType.sans(
                    size: 34,
                    weight: FontWeight.w800,
                    height: 1.05,
                    tracking: -1.2,
                  ),
                ),
                const SizedBox(height: KSpace.md),
                Text(
                  'An anonymous channel between people who witnessed something '
                  'and the stations able to act on it. We hold no identity to '
                  'hand over.',
                  style: KType.sans(size: 13.5, color: KC.muted, height: 1.5),
                ),
                const SizedBox(height: KSpace.xl),
                KPanel(
                  title: 'Zero-knowledge status',
                  trailing: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LiveDot(),
                      SizedBox(width: 6),
                      MonoBadge('ARMED', color: KC.accent, dense: true),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: KSpace.md,
                    vertical: KSpace.sm,
                  ),
                  child: Column(
                    children: [
                      for (final (title, detail) in _guarantees)
                        _GuaranteeRow(title: title, detail: detail),
                    ],
                  ),
                ),
                const Spacer(),
                KButton(
                  label: 'File anonymous report',
                  icon: Icons.north_east_rounded,
                  onPressed: () => _open(context, ShellTab.report),
                ),
                const SizedBox(height: KSpace.sm),
                Row(
                  children: [
                    Expanded(
                      child: KButton(
                        label: 'Track case',
                        kind: KButtonKind.outline,
                        icon: Icons.search_rounded,
                        onPressed: () => _open(context, ShellTab.track),
                      ),
                    ),
                    const SizedBox(width: KSpace.sm),
                    Expanded(
                      child: KButton(
                        label: 'Get help now',
                        kind: KButtonKind.outline,
                        icon: Icons.support_agent_rounded,
                        onPressed: () => _open(context, ShellTab.resources),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: KSpace.md),
                Text(
                  'IF YOU ARE IN IMMEDIATE DANGER, CONTACT LOCAL EMERGENCY SERVICES FIRST.',
                  textAlign: TextAlign.center,
                  style: KType.mono(size: 8.5, color: KC.faint, tracking: 0.7, height: 1.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WordmarkBar extends StatelessWidget {
  const _WordmarkBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: KC.accent.withValues(alpha: 0.12),
            border: Border.all(color: KC.accent),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            'K',
            style: KType.mono(size: 14, weight: FontWeight.w800, color: KC.accent),
          ),
        ),
        const SizedBox(width: KSpace.sm),
        Text(
          KasatConfig.appName,
          style: KType.mono(size: 15, weight: FontWeight.w800, tracking: 3.5),
        ),
        const Spacer(),
        const MonoBadge(KasatConfig.buildChannel, color: KC.faint, size: 9),
      ],
    );
  }
}

class _GuaranteeRow extends StatelessWidget {
  const _GuaranteeRow({required this.title, required this.detail});

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(Icons.check_rounded, size: 13, color: KC.accent),
          ),
          const SizedBox(width: KSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: KType.mono(size: 10.5, weight: FontWeight.w700, tracking: 0.9),
                ),
                const SizedBox(height: 2),
                Text(detail, style: KType.sans(size: 11.5, color: KC.muted, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
