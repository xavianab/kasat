import 'package:flutter/material.dart';

import '../../app.dart';
import '../../models/country.dart';
import '../../theme/kasat_theme.dart';
import '../../widgets/kasat_button.dart';
import '../../widgets/panel.dart';
import '../../widgets/soft_backdrop.dart';
import '../../widgets/soft_badge.dart';
import '../accounts/account_setup_view.dart';
import '../connectivity/offline_banner.dart';
import '../more/more_menu.dart';
import '../settings/settings_view.dart';
import '../shell/shell_view.dart';
import '../vent/vent_feed_view.dart';

class WelcomeView extends StatelessWidget {
  const WelcomeView({super.key, this.offline = false});

  final bool offline;

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
    final scope = KasatScope.of(context);
    final country = countryByCode(scope.settings.countryCode);
    final i18n = scope.i18n;

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
                        GestureDetector(
                          key: MoreMenu.buttonKey,
                          onTap: () => MoreMenu.open(context),
                          child: SoftBadge(
                            i18n.t('welcome.more'),
                            icon: Icons.menu_rounded,
                            color: KC.muted,
                            dense: true,
                          ),
                        ),
                        if (country != null) ...[
                          const SizedBox(width: KSpace.sm),
                          GestureDetector(
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const SettingsView(),
                              ),
                            ),
                            child: SoftBadge(
                              country.name,
                              icon: Icons.place_outlined,
                              color: KC.secondary,
                              dense: true,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: KSpace.xxl),
                    FutureBuilder<int>(
                      future: scope.repository.queuedCount(),
                      builder: (context, snap) => OfflineBanner(
                        offline: offline,
                        queued: snap.data ?? 0,
                      ),
                    ),
                    Text(
                      i18n.t('welcome.title'),
                      style: KType.serif(size: 40, height: 1.15, weight: FontWeight.w600),
                    ),
                    const SizedBox(height: KSpace.lg),
                    Text(
                      i18n.t('welcome.blurb'),
                      style: KType.sans(size: 15.5, color: KC.muted, height: 1.6),
                    ),
                    if (!scope.identity.hasIdentity) ...[
                      const SizedBox(height: KSpace.lg),
                      GestureDetector(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const AccountSetupView(),
                          ),
                        ),
                        child: Text(
                          i18n.t('account.title'),
                          style: KType.sans(size: 13.5, color: KC.primary, weight: FontWeight.w600),
                        ),
                      ),
                    ],
                    const SizedBox(height: KSpace.xl),
                    KPanel(
                      title: i18n.t('welcome.promises'),
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
                      label: i18n.t('welcome.report'),
                      icon: Icons.edit_outlined,
                      onPressed: () => _open(context, ShellTab.report),
                    ),
                    const SizedBox(height: KSpace.sm),
                    Row(
                      children: [
                        Expanded(
                          child: KButton(
                            label: i18n.t('welcome.track'),
                            kind: KButtonKind.soft,
                            icon: Icons.search_rounded,
                            compact: true,
                            onPressed: () => _open(context, ShellTab.track),
                          ),
                        ),
                        const SizedBox(width: KSpace.sm),
                        Expanded(
                          child: KButton(
                            label: i18n.t('welcome.help'),
                            kind: KButtonKind.secondary,
                            icon: Icons.favorite_outline_rounded,
                            compact: true,
                            onPressed: () => _open(context, ShellTab.resources),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: KSpace.sm),
                    KButton(
                      label: i18n.t('welcome.notices'),
                      kind: KButtonKind.soft,
                      icon: Icons.campaign_outlined,
                      compact: true,
                      onPressed: () => _open(context, ShellTab.alerts),
                    ),
                    const SizedBox(height: KSpace.sm),
                    KButton(
                      label: i18n.t('welcome.vent'),
                      kind: KButtonKind.ghost,
                      icon: Icons.chat_bubble_outline_rounded,
                      compact: true,
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => const VentFeedView()),
                      ),
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
