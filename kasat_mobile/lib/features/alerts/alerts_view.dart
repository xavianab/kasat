import 'dart:async';

import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/kasat_config.dart';
import '../../core/time_format.dart';
import '../../models/community_alert.dart';
import '../../theme/kasat_theme.dart';
import '../../widgets/kasat_button.dart';
import '../../widgets/panel.dart';
import '../../widgets/soft_badge.dart';
import 'compose_alert_view.dart';
import 'tip_sheet.dart';

class AlertsView extends StatefulWidget {
  const AlertsView({super.key});

  @override
  State<AlertsView> createState() => _AlertsViewState();
}

class _AlertsViewState extends State<AlertsView> {
  List<CommunityAlert> _live = const [];
  List<CommunityAlert> _pending = const [];
  List<AlertTip> _tips = const [];
  StreamSubscription<void>? _watch;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bind());
  }

  @override
  void dispose() {
    _watch?.cancel();
    super.dispose();
  }

  void _bind() {
    final scope = KasatScope.of(context);
    _watch = scope.alerts.watch().listen((_) {
      if (mounted) _reload();
    });
    _reload();
  }

  Future<void> _reload() async {
    final scope = KasatScope.of(context);
    final country = scope.settings.countryCode;
    final token = scope.settings.posterToken();
    final live = country == null ? <CommunityAlert>[] : await scope.alerts.liveForCountry(country);
    final pending =
        KasatConfig.placeholderVerifiedPoster ? await scope.alerts.pending() : const <CommunityAlert>[];
    final tips =
        KasatConfig.placeholderVerifiedPoster ? await scope.alerts.tipsForPoster(token) : const <AlertTip>[];
    if (!mounted) return;
    setState(() {
      _live = live;
      _pending = pending;
      _tips = tips;
    });
  }

  @override
  Widget build(BuildContext context) {
    final verified = KasatConfig.placeholderVerifiedPoster;

    return ListView(
      padding: const EdgeInsets.fromLTRB(KSpace.lg, KSpace.xs, KSpace.lg, KSpace.xxl),
      children: [
        Text(
          'Notices from people who have been checked. There is no chat here — '
          'only a short post, and a private note if you have something to add.',
          style: KType.sans(size: 14, color: KC.muted, height: 1.5),
        ),
        if (verified) ...[
          const SizedBox(height: KSpace.lg),
          KButton(
            label: 'Post a notice',
            icon: Icons.edit_outlined,
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const ComposeAlertView()),
              );
              if (mounted) _reload();
            },
          ),
        ],
        if (_pending.isNotEmpty) ...[
          const SizedBox(height: KSpace.xl),
          Text('Waiting for a person', style: KType.serif(size: 20)),
          const SizedBox(height: KSpace.xs),
          Text(
            'The first look was unsure. These stay off the feed until someone reads them.',
            style: KType.sans(size: 13, color: KC.muted, height: 1.45),
          ),
          const SizedBox(height: KSpace.md),
          for (final alert in _pending) _AlertCard(alert: alert, pending: true, onChanged: _reload),
        ],
        const SizedBox(height: KSpace.xl),
        Text('Open notices', style: KType.serif(size: 20)),
        const SizedBox(height: KSpace.md),
        if (_live.isEmpty)
          const KNote(
            title: 'Nothing posted for your country right now',
            body: 'When a verified source shares a notice, it will appear here.',
            icon: Icons.nightlight_outlined,
            color: KC.secondary,
          )
        else
          for (final alert in _live) _AlertCard(alert: alert, onChanged: _reload),
        if (_tips.isNotEmpty) ...[
          const SizedBox(height: KSpace.xl),
          Text('Private notes to you', style: KType.serif(size: 20)),
          const SizedBox(height: KSpace.md),
          for (final tip in _tips)
            Padding(
              padding: const EdgeInsets.only(bottom: KSpace.sm),
              child: KPanel(
                padding: const EdgeInsets.all(KSpace.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tip.body, style: KType.sans(size: 14, height: 1.45)),
                    const SizedBox(height: 6),
                    Text(
                      TimeFormat.elapsed(tip.sentAt),
                      style: KType.sans(size: 12, color: KC.faint),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({
    required this.alert,
    required this.onChanged,
    this.pending = false,
  });

  final CommunityAlert alert;
  final VoidCallback onChanged;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    final scope = KasatScope.of(context);
    final mine = alert.posterToken == scope.settings.posterToken();

    return Padding(
      padding: const EdgeInsets.only(bottom: KSpace.md),
      child: KPanel(
        title: alert.title,
        subtitle: TimeFormat.elapsed(alert.postedAt),
        trailing: SoftBadge(alert.kind.label, color: KC.secondary, dense: true),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(alert.body, style: KType.sans(size: 14.5, height: 1.5, color: KC.text)),
            if (pending && alert.reviewNote != null) ...[
              const SizedBox(height: KSpace.md),
              Text(alert.reviewNote!, style: KType.sans(size: 13, color: KC.muted, height: 1.4)),
            ],
            if (!pending) ...[
              const SizedBox(height: KSpace.lg),
              Text(
                alert.seenCount == 0
                    ? 'No one has marked this yet'
                    : '${alert.seenCount} ${alert.seenCount == 1 ? 'person has' : 'people have'} seen this',
                style: KType.sans(size: 12.5, color: KC.muted),
              ),
              const SizedBox(height: KSpace.md),
              Row(
                children: [
                  Expanded(
                    child: KButton(
                      label: "I've seen this",
                      kind: KButtonKind.soft,
                      compact: true,
                      onPressed: () async {
                        await scope.alerts.markSeen(alert.id);
                        onChanged();
                      },
                    ),
                  ),
                  const SizedBox(width: KSpace.sm),
                  Expanded(
                    child: KButton(
                      label: 'Private note',
                      kind: KButtonKind.secondary,
                      compact: true,
                      onPressed: () => showTipSheet(context, alert: alert),
                    ),
                  ),
                ],
              ),
              if (mine) ...[
                const SizedBox(height: KSpace.sm),
                KButton(
                  label: 'Close this notice',
                  kind: KButtonKind.ghost,
                  compact: true,
                  onPressed: () async {
                    await scope.alerts.close(
                      alert.id,
                      posterToken: scope.settings.posterToken(),
                    );
                    onChanged();
                  },
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
