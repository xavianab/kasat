import 'package:flutter/material.dart';

import '../../app.dart';
import '../../models/country.dart';
import '../../theme/kasat_theme.dart';
import '../../widgets/kasat_button.dart';
import '../../widgets/panel.dart';
import '../../widgets/soft_backdrop.dart';
import '../../widgets/soft_badge.dart';
import '../shell/shell_view.dart';

class WelcomeView extends StatelessWidget {
  const WelcomeView({super.key});

  static const _promises = <(IconData, String, String)>[
    (
      Icons.wifi_tethering_off_rounded,
      'Nothing traces back to you',
      'No address is kept with your report, and there is no account to find.',
    ),
    (
      Icons.hide_image_outlined,
      'Photos are cleaned first',
      'Location and camera details are removed on this phone, before sending.',
    ),
    (
      Icons.vpn_key_off_outlined,
      'No name, no number',
      'You are never asked who you are — so there is nothing to hand over.',
    ),
    (
      Icons.tag_outlined,
      'Your code is made here',
      'The code that follows your case is created on this phone, not by us.',
    ),
  ];

  void _open(BuildContext context, ShellTab tab) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ShellView(initialTab: tab)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final country = countryByCode(KasatScope.of(context).settings.countryCode);

    return Scaffold(
      backgroundColor: KC.canvas,
      body: SoftBackdrop(
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                      KSpace.xl, KSpace.lg, KSpace.xl, KSpace.lg),
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: KC.primarySoft,
                            borderRadius: KRadius.rSm,
                          ),
                          child: const Icon(Icons.spa_outlined,
                              size: 21, color: KC.primary),
                        ),
                        const Spacer(),
                        if (country != null)
                          SoftBadge(
                            country.name,
                            icon: Icons.place_outlined,
                            color: KC.secondary,
                            dense: true,
                          ),
                      ],
                    ),
                    const SizedBox(height: KSpace.xxl),
                    Text(
                      'Speak\nwithout fear.',
                      style: KType.serif(size: 40, height: 1.15, weight: FontWeight.w600),
                    ),
                    const SizedBox(height: KSpace.lg),
                    Text(
                      'A quiet way to tell someone what happened — and to follow '
                      'what happens next, without ever giving your name.',
                      style: KType.sans(size: 15.5, color: KC.muted, height: 1.6),
                    ),
                    const SizedBox(height: KSpace.xl),
                    KPanel(
                      title: 'What we promise',
                      padding: const EdgeInsets.symmetric(
                          horizontal: KSpace.lg, vertical: KSpace.sm),
                      child: Column(
                        children: [
                          for (final (icon, title, detail) in _promises)
                            _PromiseRow(icon: icon, title: title, detail: detail),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    KSpace.xl, 0, KSpace.xl, KSpace.lg),
                child: Column(
                  children: [
                    KButton(
                      label: 'Tell us what happened',
                      icon: Icons.edit_outlined,
                      onPressed: () => _open(context, ShellTab.report),
                    ),
                    const SizedBox(height: KSpace.sm),
                    Row(
                      children: [
                        Expanded(
                          child: KButton(
                            label: 'Check my case',
                            kind: KButtonKind.soft,
                            icon: Icons.search_rounded,
                            compact: true,
                            onPressed: () => _open(context, ShellTab.track),
                          ),
                        ),
                        const SizedBox(width: KSpace.sm),
                        Expanded(
                          child: KButton(
                            label: 'Get help now',
                            kind: KButtonKind.secondary,
                            icon: Icons.favorite_outline_rounded,
                            compact: true,
                            onPressed: () => _open(context, ShellTab.resources),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PromiseRow extends StatelessWidget {
  const _PromiseRow({required this.icon, required this.title, required this.detail});

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: KSpace.md),
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
                Text(title, style: KType.sans(size: 14.5, weight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(detail, style: KType.sans(size: 13, color: KC.muted, height: 1.45)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
