import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app.dart';
import '../../models/country.dart';
import '../../theme/kasat_theme.dart';
import '../../widgets/kasat_button.dart';
import '../../widgets/panel.dart';
import '../../widgets/soft_backdrop.dart';
import '../../widgets/soft_badge.dart';
import '../connectivity/offline_banner.dart';
import '../more/more_menu.dart';
import '../settings/settings_view.dart';
import '../shell/shell_view.dart';

class WelcomeView extends StatelessWidget {
  const WelcomeView({super.key, this.offline = false});

  final bool offline;

  static const languageToggleKey = Key('welcome-language-toggle');

  static const _promiseKeys = <(IconData, String, String)>[
    (
      Icons.wifi_tethering_off_rounded,
      'welcome.promise1Title',
      'welcome.promise1Detail',
    ),
    (
      Icons.hide_image_outlined,
      'welcome.promise2Title',
      'welcome.promise2Detail',
    ),
    (
      Icons.vpn_key_off_outlined,
      'welcome.promise3Title',
      'welcome.promise3Detail',
    ),
    (
      Icons.tag_outlined,
      'welcome.promise4Title',
      'welcome.promise4Detail',
    ),
  ];

  void _open(BuildContext context, ShellTab tab) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ShellView(initialTab: tab)),
    );
  }

  Future<void> _toggleLanguage(BuildContext context) async {
    HapticFeedback.selectionClick();
    final i18n = KasatScope.of(context).i18n;
    final next = i18n.code == 'am' ? 'en' : 'am';
    await i18n.trySet(next);
  }

  @override
  Widget build(BuildContext context) {
    final scope = KasatScope.of(context);
    final country = countryByCode(scope.settings.effectiveCountryCode);
    final i18n = scope.i18n;

    return ListenableBuilder(
      listenable: i18n,
      builder: (context, _) {
        final countryLabel = country == null
            ? null
            : (i18n.t('country.${country.code}') != 'country.${country.code}'
                ? i18n.t('country.${country.code}')
                : country.name);

        return Scaffold(
          backgroundColor: KC.canvas,
          body: SoftBackdrop(
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      KSpace.lg,
                      KSpace.xs,
                      KSpace.lg,
                      4,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: KC.primarySoft,
                            borderRadius: KRadius.rSm,
                          ),
                          child: const Icon(
                            Icons.spa_outlined,
                            size: 16,
                            color: KC.primary,
                          ),
                        ),
                        const SizedBox(width: KSpace.xs),
                        Expanded(
                          child: Wrap(
                            alignment: WrapAlignment.end,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 5,
                            runSpacing: 4,
                            children: [
                              GestureDetector(
                                key: MoreMenu.buttonKey,
                                onTap: () => MoreMenu.open(context),
                                child: SoftBadge(
                                  i18n.t('welcome.more'),
                                  icon: Icons.menu_rounded,
                                  color: KC.muted,
                                  size: 11,
                                  dense: true,
                                ),
                              ),
                              if (country != null && countryLabel != null)
                                GestureDetector(
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => const SettingsView(),
                                    ),
                                  ),
                                  child: SoftBadge(
                                    countryLabel,
                                    icon: Icons.place_outlined,
                                    color: KC.secondary,
                                    size: 11,
                                    dense: true,
                                  ),
                                ),
                              GestureDetector(
                                key: languageToggleKey,
                                onTap: () => _toggleLanguage(context),
                                child: SoftBadge(
                                  i18n.t('welcome.langToggle'),
                                  icon: Icons.translate_rounded,
                                  color: KC.primary,
                                  size: 11,
                                  dense: true,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(
                        KSpace.lg,
                        KSpace.xs,
                        KSpace.lg,
                        KSpace.xxl + KSpace.xl,
                      ),
                      children: [
                        FutureBuilder<int>(
                          future: scope.repository.queuedCount(),
                          builder: (context, snap) => OfflineBanner(
                            offline: offline,
                            queued: snap.data ?? 0,
                          ),
                        ),
                        Text(
                          i18n.t('welcome.title'),
                          style: KType.serif(
                            size: 24,
                            height: 1.08,
                            weight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          i18n.t('welcome.blurb'),
                          style: KType.sans(
                            size: 12,
                            color: KC.muted,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: KSpace.sm),
                        KPanel(
                          title: i18n.t('welcome.promises'),
                          padding: const EdgeInsets.fromLTRB(
                            KSpace.md,
                            0,
                            KSpace.md,
                            KSpace.sm,
                          ),
                          child: Column(
                            children: [
                              for (final (icon, titleKey, detailKey)
                                  in _promiseKeys)
                                _PromiseRow(
                                  icon: icon,
                                  title: i18n.t(titleKey),
                                  detail: i18n.t(detailKey),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(
                      KSpace.lg,
                      KSpace.xs,
                      KSpace.lg,
                      KSpace.xs,
                    ),
                    decoration: BoxDecoration(
                      color: KC.canvas.withValues(alpha: 0.98),
                      border: const Border(
                        top: BorderSide(color: KC.border, width: 1),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        KButton(
                          label: i18n.t('welcome.report'),
                          icon: Icons.edit_outlined,
                          compact: true,
                          onPressed: () => _open(context, ShellTab.report),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: KButton(
                                label: i18n.t('welcome.track'),
                                kind: KButtonKind.soft,
                                icon: Icons.search_rounded,
                                compact: true,
                                maxLines: 2,
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
                                maxLines: 2,
                                onPressed: () =>
                                    _open(context, ShellTab.resources),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          i18n.t('welcome.helpNote'),
                          textAlign: TextAlign.center,
                          style: KType.sans(
                            size: 10,
                            color: KC.muted,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Expanded(
                              child: KButton(
                                label: i18n.t('welcome.notices'),
                                kind: KButtonKind.soft,
                                icon: Icons.campaign_outlined,
                                compact: true,
                                maxLines: 2,
                                onPressed: () =>
                                    _open(context, ShellTab.alerts),
                              ),
                            ),
                            const SizedBox(width: KSpace.sm),
                            Expanded(
                              child: KButton(
                                label: i18n.t('welcome.vent'),
                                kind: KButtonKind.ghost,
                                icon: Icons.chat_bubble_outline_rounded,
                                compact: true,
                                maxLines: 2,
                                onPressed: () => _open(context, ShellTab.vent),
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
      },
    );
  }
}

class _PromiseRow extends StatelessWidget {
  const _PromiseRow({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: KC.secondarySoft,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 13, color: KC.secondary),
          ),
          const SizedBox(width: KSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: KType.sans(size: 12, weight: FontWeight.w600),
                ),
                const SizedBox(height: 1),
                Text(
                  detail,
                  style: KType.sans(size: 11, color: KC.muted, height: 1.25),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
