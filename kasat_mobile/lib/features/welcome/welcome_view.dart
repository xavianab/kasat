import 'dart:async';

import 'package:flutter/material.dart';

import '../../app.dart';
import '../../models/community_alert.dart';
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

class HomeTabContent extends StatefulWidget {
  const HomeTabContent({
    super.key,
    required this.offline,
    required this.onSelectTab,
  });

  final bool offline;
  final ValueChanged<ShellTab> onSelectTab;

  @override
  State<HomeTabContent> createState() => _HomeTabContentState();
}

class _HomeTabContentState extends State<HomeTabContent> {
  List<CommunityAlert> _tips = const [];
  StreamSubscription<void>? _watch;
  KasatScope? _boundScope;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = KasatScope.of(context);
    if (_boundScope != scope) {
      _watch?.cancel();
      _boundScope = scope;
      _watch = scope.alerts.watch().listen((_) {
        if (mounted) _loadTips();
      });
    }
    _loadTips();
  }

  @override
  void dispose() {
    _watch?.cancel();
    super.dispose();
  }

  Future<void> _loadTips() async {
    final scope = KasatScope.of(context);
    final code = scope.settings.effectiveCountryCode;
    final list = await scope.alerts.liveForCountry(code);
    if (!mounted) return;
    setState(() => _tips = list);
  }

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
            FutureBuilder<int>(
              future: scope.repository.queuedCount(),
              builder: (context, snap) => OfflineBanner(
                offline: widget.offline,
                queued: snap.data ?? 0,
              ),
            ),
            KButton(
              label: i18n.t('welcome.report'),
              icon: Icons.edit_outlined,
              onPressed: () => widget.onSelectTab(ShellTab.report),
            ),
            const SizedBox(height: KSpace.sm),
            KButton(
              label: i18n.t('welcome.track'),
              kind: KButtonKind.secondary,
              icon: Icons.schedule_outlined,
              onPressed: () => widget.onSelectTab(ShellTab.track),
            ),
            const SizedBox(height: KSpace.sm),
            KButton(
              label: i18n.t('welcome.help'),
              kind: KButtonKind.soft,
              icon: Icons.favorite_outline_rounded,
              onPressed: () => widget.onSelectTab(ShellTab.resources),
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
            if (_tips.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: KSpace.sm),
                child: Text(
                  'No safety tips posted right now.',
                  style: KType.sans(size: 13.5, color: KC.muted, height: 1.45),
                ),
              )
            else
              for (var i = 0; i < _tips.length; i++) ...[
                _SafetyTipRow(alert: _tips[i]),
                if (i < _tips.length - 1) const KRule(height: KSpace.md),
              ],
          ],
        );
      },
    );
  }
}

class _SafetyTipRow extends StatelessWidget {
  const _SafetyTipRow({required this.alert});

  final CommunityAlert alert;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: KSpace.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            alert.title,
            style: KType.sans(size: 14, weight: FontWeight.w600, height: 1.35),
          ),
          const SizedBox(height: 4),
          Text(
            alert.body,
            style: KType.sans(size: 13, color: KC.muted, height: 1.45),
          ),
        ],
      ),
    );
  }
}
