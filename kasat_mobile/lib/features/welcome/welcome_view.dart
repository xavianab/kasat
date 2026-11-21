import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/kasat_config.dart';
import '../../theme/kasat_theme.dart';
import '../../widgets/kasat_button.dart';
import '../../widgets/panel.dart';
import '../connectivity/offline_banner.dart';
import '../shell/shell_view.dart';

class WelcomeView extends StatelessWidget {
  const WelcomeView({super.key, this.offline = false});

  final bool offline;

  static const languageToggleKey = Key('welcome-language-toggle');

  @override
  Widget build(BuildContext context) {
    return ShellView(initialTab: ShellTab.home, offline: offline);
  }
}

class HomeTabContent extends StatelessWidget {
  const HomeTabContent({
    super.key,
    required this.offline,
    required this.onSelectTab,
    this.testBuild = KasatConfig.testBuild,
  });

  static const testBannerKey = Key('test-build-banner');

  static const _tipKeys = <(String, String)>[
    ('welcome.tip1Title', 'welcome.tip1Body'),
    ('welcome.tip2Title', 'welcome.tip2Body'),
    ('welcome.tip3Title', 'welcome.tip3Body'),
  ];

  final bool offline;
  final ValueChanged<ShellTab> onSelectTab;
  final bool testBuild;

  @override
  Widget build(BuildContext context) {
    final scope = KasatScope.of(context);
    final i18n = scope.i18n;

    return ListenableBuilder(
      listenable: i18n,
      builder: (context, _) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(
            KSpace.lg,
            KSpace.lg,
            KSpace.lg,
            KSpace.xxl,
          ),
          children: [
            if (testBuild) ...[
              Container(
                key: HomeTabContent.testBannerKey,
                padding: const EdgeInsets.symmetric(
                  horizontal: KSpace.md,
                  vertical: KSpace.sm,
                ),
                decoration: BoxDecoration(
                  color: KC.surface,
                  borderRadius: KRadius.rMd,
                  border: Border.all(color: KC.border),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.science_outlined,
                      size: 16,
                      color: KC.muted,
                    ),
                    const SizedBox(width: KSpace.sm),
                    Expanded(
                      child: Text(
                        "Test version. Don't report real incidents.",
                        style: KType.sans(
                          size: 12.5,
                          weight: FontWeight.w600,
                          color: KC.text,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: KSpace.md),
            ],
            FutureBuilder<int>(
              future: scope.repository.queuedCount(),
              builder: (context, snap) => OfflineBanner(
                offline: offline,
                queued: snap.data ?? 0,
              ),
            ),
            KButton(
              label: i18n.t('welcome.report'),
              icon: Icons.edit_outlined,
              onPressed: () => onSelectTab(ShellTab.report),
            ),
            const SizedBox(height: KSpace.sm),
            KButton(
              label: i18n.t('welcome.track'),
              kind: KButtonKind.secondary,
              icon: Icons.schedule_outlined,
              onPressed: () => onSelectTab(ShellTab.track),
            ),
            const SizedBox(height: KSpace.sm),
            KButton(
              label: i18n.t('welcome.help'),
              kind: KButtonKind.soft,
              icon: Icons.favorite_outline_rounded,
              onPressed: () => onSelectTab(ShellTab.resources),
            ),
            const SizedBox(height: KSpace.md),
            Text(
              'Free. Anonymous. You decide who sees your report.',
              textAlign: TextAlign.center,
              style: KType.sans(size: 12.5, color: KC.muted, height: 1.4),
            ),
            const SizedBox(height: KSpace.xl),
            Text(
              i18n.t('welcome.notices'),
              style: KType.sans(size: 16, weight: FontWeight.w600),
            ),
            const SizedBox(height: KSpace.sm),
            for (var i = 0; i < _tipKeys.length; i++) ...[
              _SafetyTipRow(
                title: i18n.t(_tipKeys[i].$1),
                body: i18n.t(_tipKeys[i].$2),
              ),
              if (i < _tipKeys.length - 1) const KRule(height: KSpace.md),
            ],
          ],
        );
      },
    );
  }
}

class _SafetyTipRow extends StatelessWidget {
  const _SafetyTipRow({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: KSpace.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: KType.sans(size: 14, weight: FontWeight.w600, height: 1.35),
          ),
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
