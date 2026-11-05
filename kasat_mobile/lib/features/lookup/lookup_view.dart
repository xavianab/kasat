import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app.dart';
import '../../core/kasat_config.dart';
import '../../core/time_format.dart';
import '../../core/update_notifier.dart';
import '../../core/tracking_id.dart';
import '../../models/incident.dart';
import '../../theme/kasat_theme.dart';
import '../../widgets/k_field.dart';
import '../../widgets/kasat_button.dart';
import '../../widgets/panel.dart';
import '../../widgets/soft_badge.dart';
import '../../widgets/status_pill.dart';
import '../identity/reveal_identity_sheet.dart';
import '../lock/pin_setup_sheet.dart';

class LookupView extends StatefulWidget {
  const LookupView({super.key});

  @override
  State<LookupView> createState() => LookupViewState();
}

class LookupViewState extends State<LookupView> {
class _MessageRefresh {
  final List<Future<void> Function()> _runs = [];

  void bind(Future<void> Function() run) {
    _runs.remove(run);
    _runs.add(run);
  }

  void unbind(Future<void> Function() run) {
    _runs.remove(run);
  }

  Future<void> call() async {
    for (final run in List<Future<void> Function()>.of(_runs)) {
      await run();
    }
  }
}

  final _controller = TextEditingController();

  final _messages = _MessageRefresh();
  String? _resolvedId;
  bool _searching = false;
  bool _notFound = false;
  List<String> _localIds = const [];
  KasatScope? _registeredScope;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadLocalIds());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = KasatScope.of(context);
    if (_registeredScope != scope) {
      _registeredScope?.unregisterWipeCallback(_wipeState);
      _registeredScope = scope;
      scope.registerWipeCallback(_wipeState);
    }
  }

  @override
  void dispose() {
    _registeredScope?.unregisterWipeCallback(_wipeState);
    _controller.dispose();
    super.dispose();
  }

  void _wipeState() {
    _controller.clear();
    if (mounted) {
      setState(() {
        _resolvedId = null;
        _notFound = false;
      });
    }
  }

  Future<void> _loadLocalIds() async {
    final ids = await KasatScope.of(context).repository.localTrackingIds();
    if (!mounted) return;
    setState(() => _localIds = ids);
  }

  /// Entry point used by the shell after a successful submission or when a
  /// tracking code chip is tapped.
  /// Issue 3 safety rule: Do NOT gate tracking-code lookup behind the PIN.
  /// A valid tracking code is itself the credential; the PIN protects only the
  /// saved-history list on this device.
  Future<void> loadTrackingId(String trackingId) async {
    _controller.text = trackingId;
    await _loadLocalIds();
    await _resolve();
  }

  Future<void> _resolve() async {
    final normalized = TrackingId.normalize(_controller.text);
    FocusScope.of(context).unfocus();

    if (normalized == null) {
      setState(() {
        _resolvedId = null;
        _notFound = true;
      });
      return;
    }

    setState(() {
      _searching = true;
      _notFound = false;
      _resolvedId = null;
    });

    final incident =
        await KasatScope.of(context).repository.lookup(normalized);
    if (!mounted) return;

    setState(() {
      _searching = false;
      _resolvedId = incident == null ? null : normalized;
      _notFound = incident == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scope = KasatScope.of(context);
    final unlocked = scope.settings.hasPin && scope.isPinSessionUnlocked;

    return ListView(
    return RefreshIndicator(
      onRefresh: _messages.call,
      child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
          const EdgeInsets.fromLTRB(KSpace.lg, KSpace.xs, KSpace.lg, KSpace.xxl),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Enter the code you were given when you sent your report. '
                'Your tracking code works anytime without a PIN.',
                style: KType.sans(size: 14, color: KC.muted, height: 1.5),
              ),
            ),
            if (unlocked) ...[
              const SizedBox(width: KSpace.sm),
              GestureDetector(
                onTap: () => scope.lockPinSession(),
                child: const SoftBadge(
                  'Lock history',
                  icon: Icons.lock_outline_rounded,
                  color: KC.muted,
                  dense: true,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: KSpace.lg),
        KPanel(
          title: 'Your code',
          subtitle: 'Type your KST-XXXXX code directly — no PIN required.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              KTextField(
                controller: _controller,
                hint: 'KST-8X9P2',
                code: true,
                textAlign: TextAlign.center,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  UpperCaseFormatter(),
                  LengthLimitingTextInputFormatter(12),
                ],
                onChanged: (_) => setState(() => _notFound = false),
              ),
              const SizedBox(height: KSpace.md),
              KButton(
                label: 'Look it up',
                icon: Icons.search_rounded,
                busy: _searching,
                onPressed: _controller.text.trim().isEmpty ? null : _resolve,
              ),
              if (_localIds.isNotEmpty) ...[
                const KRule(),
                const KFieldLabel('Saved on this phone'),
                if (unlocked)
                  Wrap(
                    spacing: KSpace.sm,
                    runSpacing: KSpace.sm,
                    children: [
                      for (final id in _localIds.take(6))
                        GestureDetector(
                          onTap: () => loadTrackingId(id),
                          child: CodeChip(id),
                        ),
                    ],
                  )
                else
                  _PinGateCard(
                    hasPin: scope.settings.hasPin,
                    savedCount: _localIds.length,
                    onUnlockPressed: () async {
                      final ok = await PinGuard.ensureUnlocked(context);
                      if (mounted && ok) {
                        await _loadLocalIds();
                        setState(() {});
                      }
                    },
                  ),
              ],
            ],
          ),
        ),
        const SizedBox(height: KSpace.md),
        if (_notFound) const _NotFoundCard(),
        if (_resolvedId != null) _LiveCase(trackingId: _resolvedId!),
        if (_resolvedId != null)
          _LiveCase(trackingId: _resolvedId!, messages: _messages),
        if (_resolvedId == null && !_notFound && !_searching) const _DemoHint(),
      ],
      ),
  }
}

class _PinGateCard extends StatelessWidget {
  const _PinGateCard({
    required this.hasPin,
    required this.savedCount,
    required this.onUnlockPressed,
  });

  static const unlockButtonKey = Key('unlock-history-button');

  final bool hasPin;
  final int savedCount;
  final VoidCallback onUnlockPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(KSpace.md),
      decoration: BoxDecoration(
        color: KC.surfaceAlt,
        borderRadius: KRadius.rMd,
        border: Border.all(color: KC.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            hasPin
                ? 'Saved history ($savedCount on this phone) is locked behind your 6-digit PIN. Or type your written tracking code above without a PIN.'
                : 'Protect your saved history list ($savedCount on this phone) with a 6-digit PIN so nobody else who picks up this phone can see it.',
            style: KType.sans(size: 13, color: KC.muted, height: 1.45),
          ),
          const SizedBox(height: KSpace.md),
          KButton(
            key: unlockButtonKey,
            label: hasPin
                ? 'Unlock saved history on this phone'
                : 'Set 6-digit PIN to view saved history',
            kind: KButtonKind.secondary,
            compact: true,
            icon: Icons.lock_open_rounded,
            onPressed: onUnlockPressed,
          ),
        ],
      ),
    );
  }
}

/// Keeps the tracking field uppercase as it is typed, so a code copied from a
/// note app matches without the survivor thinking about case.
class UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}

class _LiveCase extends StatefulWidget {
  const _LiveCase({required this.trackingId});
  const _LiveCase({required this.trackingId, required this.messages});

  final String trackingId;
  final _MessageRefresh messages;
  @override
  State<_LiveCase> createState() => _LiveCaseState();
}

class _LiveCaseState extends State<_LiveCase> {
  Stream<Incident?>? _stream;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _stream ??= KasatScope.of(context).repository.watch(widget.trackingId);
  }

  @override
  void didUpdateWidget(_LiveCase oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trackingId != widget.trackingId) {
      _stream = KasatScope.of(context).repository.watch(widget.trackingId);
    }
  }

  Future<void> _openReveal(Incident incident) async {
    final updated = await RevealIdentityScreen.open(context, incident);
    if (updated != null && mounted) {
      setState(() {
        _stream = KasatScope.of(context).repository.watch(widget.trackingId);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Incident?>(
      stream: _stream,
      builder: (context, snapshot) {
        final incident = snapshot.data;
        if (incident == null) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            KPanel(
              title: 'Your case',
              trailing: StatusPill(incident.status, live: true),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CodeChip(incident.trackingId, size: 15),
                  const SizedBox(height: KSpace.lg),
                  StatusTrack(incident.status),
                  if (incident.accessSecret != null &&
                      incident.accessSecret!.isNotEmpty &&
                      KasatConfig.supabaseUrl.isNotEmpty &&
                      KasatConfig.supabaseAnonKey.isNotEmpty)
                    _CaseProgress(
                      accessSecret: incident.accessSecret!,
                      messages: widget.messages,
                    )
                  else
                    StatusTrack(incident.status),
                  Text(
                    incident.status.blurb,
                    style: KType.sans(size: 13.5, color: KC.muted, height: 1.5),
                  ),
                  const KRule(height: KSpace.lg),
                  KMetaRow('Kind', incident.category.label),
                  KMetaRow(
                    'Priority',
                    incident.priority.label,
                    valueColor: incident.priority.color,
                  ),
                  KMetaRow('Sent', TimeFormat.stamp(incident.submittedAt)),
                  KMetaRow(
                    'Last change',
                    TimeFormat.elapsed(incident.updatedAt),
                  ),
                  KMetaRow(
                    'With',
                    incident.assignedStation ?? 'Not yet assigned',
                  ),
                  if (incident.location != null)
                    KMetaRow('Location', incident.location!.displayLabel),
                  if (incident.evidenceSha256 != null)
                    KMetaRow(
                      'Server SHA-256',
                      '${incident.evidenceSha256!.substring(0, 16)}… (authoritative)',
                      valueColor: KC.calm,
                    )
                  else if (incident.clientEvidenceSha256 != null)
                    KMetaRow(
                      'Transport SHA-256',
                      '${incident.clientEvidenceSha256!.substring(0, 16)}… (pending server verify)',
                    ),
                ],
              ),
            ),
            const SizedBox(height: KSpace.md),
            KPanel(
              title: 'Identity on this report',
              subtitle: incident.identityRevealed
                  ? 'Named (shared with police — permanent)'
                  : 'Anonymous (no name or phone attached)',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (incident.identityRevealed) ...[
                    Text(
                      'You chose to share your identity with police for this '
                      'report${incident.revealedName != null ? ' (${incident.revealedName})' : ''}. '
                      'This is one-way and cannot be undone.',
                      style: KType.sans(
                        size: 13.5,
                        color: KC.muted,
                        height: 1.5,
                      ),
                    ),
                  ] else ...[
                    Text(
                      'This report is completely anonymous. If you want police '
                      'to know who you are and how to contact you on this '
                      'specific case, you can reveal your identity. This is '
                      'one-way and cannot be undone.',
                      style: KType.sans(
                        size: 13.5,
                        color: KC.muted,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: KSpace.md),
                    KButton(
                      key: RevealIdentityScreen.revealButtonKey,
                      label: 'Reveal my identity to police',
                      kind: KButtonKind.secondary,
                      icon: Icons.badge_outlined,
                      compact: true,
                      onPressed: () => _openReveal(incident),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: KSpace.md),
            if (incident.accessSecret != null &&
                incident.accessSecret!.isNotEmpty &&
                KasatConfig.supabaseUrl.isNotEmpty &&
                KasatConfig.supabaseAnonKey.isNotEmpty) ...[
              const SizedBox(height: KSpace.md),
              _CaseReplies(
                accessSecret: incident.accessSecret!,
                messages: widget.messages,
              ),
            ],
            KPanel(
              title: 'What has happened so far',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = incident.history.length - 1; i >= 0; i--)
                    _HistoryRow(
                      event: incident.history[i],
                      latest: i == incident.history.length - 1,
                      last: i == 0,
                    ),
                ],
              ),
            ),
            const SizedBox(height: KSpace.md),
            KPanel(
              title: 'What you wrote',
              child: Text(
                incident.description,
                style: KType.sans(size: 13.5, color: KC.muted, height: 1.6),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.event,
    required this.latest,
    required this.last,
  });

  final StatusEvent event;
  final bool latest;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 11,
              height: 11,
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: latest ? event.status.color : KC.surface,
                border: Border.all(color: event.status.color, width: 2),
                shape: BoxShape.circle,
              ),
            ),
            if (!last)
              Container(
                width: 2,
                height: 34,
                margin: const EdgeInsets.symmetric(vertical: 4),
                color: KC.border,
              ),
          ],
        ),
        const SizedBox(width: KSpace.md),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: last ? 0 : KSpace.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        event.status.label,
                        style: KType.sans(
                          size: 13.5,
                          weight: FontWeight.w600,
                          color: event.status.color,
                        ),
                      ),
                    ),
                    Text(
                      TimeFormat.stamp(event.at),
                      style: KType.sans(size: 11.5, color: KC.faint),
                    ),
                  ],
                ),
                if (event.note != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    event.note!,
                    style: KType.sans(
                      size: 13,
                      color: KC.muted,
                      height: 1.45,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _NotFoundCard extends StatelessWidget {
class _CaseProgress extends StatefulWidget {
  const _CaseProgress({required this.accessSecret, required this.messages});

  final String accessSecret;
  final _MessageRefresh messages;

  @override
  State<_CaseProgress> createState() => _CaseProgressState();
}

class _CaseProgressState extends State<_CaseProgress> with WidgetsBindingObserver {
  final _remote = RemoteReportsClient();
  CaseProgress? _progress;
  bool _loading = true;
  String? _error;
  Timer? _timer;
  late final Future<void> Function() _reload;

  @override
  void initState() {
    super.initState();
    _reload = reload;
    widget.messages.bind(_reload);
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => reload());
    reload();
  }

  @override
  void didUpdateWidget(_CaseProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    widget.messages.bind(_reload);
    if (oldWidget.accessSecret != widget.accessSecret) reload();
  }

  @override
  void dispose() {
    widget.messages.unbind(_reload);
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) reload();
  }

  Future<void> reload() async {
    try {
      final progress = await _remote.getMyCaseStatus(widget.accessSecret);
      if (!mounted) return;
      setState(() {
        _progress = progress;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Progress could not be loaded.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _progress;
    if (_loading && progress == null) {
      return Text('Checking progress…', style: KType.sans(size: 13.5, color: KC.muted));
    }
    if (progress == null) {
      return Text(
        _error ?? 'Progress could not be loaded.',
        style: KType.sans(size: 13.5, color: KC.urgent, height: 1.4),
      );
    }
    final steps = _progressSteps(progress);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < steps.length; i++)
          _ProgressRow(step: steps[i], last: i == steps.length - 1),
        if (_error != null) ...[
          const SizedBox(height: KSpace.sm),
          Text(_error!, style: KType.sans(size: 13, color: KC.urgent, height: 1.4)),
        ],
      ],
    );
  }
}

class _ProgressStep {
  const _ProgressStep({
    required this.label,
    required this.at,
    required this.reached,
    required this.current,
  });

  final String label;
  final DateTime? at;
  final bool reached;
  final bool current;
}

List<_ProgressStep> _progressSteps(CaseProgress progress) {
  final labels = <(String, DateTime?)>[
    ('Sent', progress.sentAt),
    ('Received by the station', progress.sentAt),
    ('An officer is handling your case', progress.claimedAt),
    ('Officer on the way', progress.enRouteAt),
    ('Officer on scene', progress.onSceneAt),
    ('Resolved', progress.resolvedAt),
  ];
  if (progress.reopened) labels.add(('Reopened', null));

  final current = progress.reopened
      ? labels.length - 1
      : switch (progress.dispatchStatus) {
          'resolved' => 5,
          'on_scene' => 4,
          'en_route' => 3,
          'claimed' => 2,
          _ => progress.status == 'resolved' ? 5 : 1,
        };

  return [
    for (var i = 0; i < labels.length; i++)
      _ProgressStep(
        label: labels[i].$1,
        at: labels[i].$2,
        reached: i <= current,
        current: i == current,
      ),
  ];
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({required this.step, required this.last});

  final _ProgressStep step;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final color = step.current
        ? KC.primary
        : step.reached
            ? KC.text
            : KC.faint;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 18,
            child: Column(
              children: [
                Container(
                  width: step.current ? 12 : 9,
                  height: step.current ? 12 : 9,
                  margin: EdgeInsets.only(top: step.current ? 3 : 4),
                  decoration: BoxDecoration(
                    color: step.reached ? color : KC.surface,
                    border: Border.all(color: step.reached ? color : KC.borderStrong, width: 2),
                    shape: BoxShape.circle,
                  ),
                ),
                if (!last)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      color: step.reached ? KC.borderStrong : KC.border,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: KSpace.sm),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : KSpace.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.label,
                    style: KType.sans(
                      size: 13.5,
                      weight: step.current ? FontWeight.w700 : FontWeight.w500,
                      color: color,
                      height: 1.3,
                    ),
                  ),
                  if (step.reached && step.at != null)
                    Text(
                      TimeFormat.stamp(step.at!),
                      style: KType.sans(size: 11.5, color: KC.faint),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CaseReplies extends StatefulWidget {
  const _CaseReplies({required this.accessSecret, required this.messages});

  final String accessSecret;
  final _MessageRefresh messages;

  @override
  State<_CaseReplies> createState() => _CaseRepliesState();
}

class _CaseRepliesState extends State<_CaseReplies> with WidgetsBindingObserver {
  final _reply = TextEditingController();
  final _remote = RemoteReportsClient();
  List<SurvivorReply> _rows = const [];
  Set<String> _seenOfficer = const {};
  bool _hasBaseline = false;
  bool _foreground = true;
  bool _loading = true;
  bool _sending = false;
  String? _error;
  Timer? _timer;
  late final Future<void> Function() _reload;

  @override
  void initState() {
    super.initState();
    _reload = reload;
    widget.messages.bind(_reload);
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => reload());
    reload();
  }

  @override
  void didUpdateWidget(_CaseReplies oldWidget) {
    super.didUpdateWidget(oldWidget);
    widget.messages.bind(_reload);
    if (oldWidget.accessSecret != widget.accessSecret) reload();
  }

  @override
  void dispose() {
    widget.messages.unbind(_reload);
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _reply.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    _foreground = foreground;
    if (foreground) reload();
  }

  String _officerKey(SurvivorReply row) =>
      '${row.createdAt.toUtc().toIso8601String()}|${row.body}';

  Future<void> reload() async {
    try {
      final rows = await _remote.listSurvivorReplies(widget.accessSecret);
      if (!mounted) return;
      final officer = rows.where((row) => row.sender == 'officer').map(_officerKey).toSet();
      final fresh = officer.difference(_seenOfficer);
      final notify = _hasBaseline && fresh.isNotEmpty && !_foreground;
      _seenOfficer = officer;
      _hasBaseline = true;
      setState(() {
        _rows = rows;
        _loading = false;
        _error = null;
      });
      if (notify && KasatScope.of(context).settings.updateNotificationsEnabled) {
        await UpdateNotifier.show();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Replies could not be loaded.';
      });
    }
  }

  Future<void> _send() async {
    final text = _reply.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await _remote.sendSurvivorReply(widget.accessSecret, text);
      _reply.clear();
      await reload();
      if (!mounted) return;
      setState(() => _sending = false);
    } catch (error) {
      if (!mounted) return;
      final tooMany = error.toString().contains('too many messages');
      setState(() {
        _sending = false;
        _error = tooMany
            ? 'That is enough messages for now. Try again in a little while.'
            : 'That reply did not send.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return KPanel(
      title: 'Messages',
      subtitle: 'Replies from the station, and your answers.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_loading)
            Text('Loading messages…', style: KType.sans(size: 13.5, color: KC.muted))
          else if (_rows.isEmpty)
            Text(
              'No messages yet.',
              style: KType.sans(size: 13.5, color: KC.muted, height: 1.45),
            )
          else
            for (final row in _rows) ...[
              Text(
                row.sender == 'survivor' ? 'You' : 'Officer',
                style: KType.sans(size: 12.5, weight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(row.body, style: KType.sans(size: 13.5, height: 1.45)),
              Text(
                TimeFormat.stamp(row.createdAt.toLocal()),
                style: KType.sans(size: 11.5, color: KC.faint),
              ),
              const SizedBox(height: KSpace.sm),
            ],
          if (_error != null) ...[
            const SizedBox(height: KSpace.sm),
            Text(_error!, style: KType.sans(size: 13, color: KC.urgent, height: 1.4)),
          ],
          const SizedBox(height: KSpace.md),
          KTextField(
            controller: _reply,
            hint: 'Write a reply',
            maxLines: 3,
          ),
          const SizedBox(height: KSpace.sm),
          KButton(
            label: 'Send reply',
            icon: Icons.reply_rounded,
            kind: KButtonKind.secondary,
            busy: _sending,
            onPressed: _sending ? null : _send,
          ),
        ],
      ),
    );
  }
}

  const _NotFoundCard();

  @override
  Widget build(BuildContext context) {
    return const KNote(
      title: 'No case with that code',
      icon: Icons.help_outline_rounded,
      color: KC.secondary,
      body: 'Codes are five characters after KST, and they never contain the '
          'letters O, I, L or U, or the digits 0 and 1 — those are too easy to '
          'mistake for each other. Check the code and try again.',
    );
  }
}

class _DemoHint extends StatelessWidget {
  const _DemoHint();

  @override
  Widget build(BuildContext context) {
    return KPanel(
      title: 'Example cases',
      subtitle: 'Included with this build so you can see how tracking looks.',
      child: const Row(
        children: [
          CodeChip('KST-4RT7Q'),
          SizedBox(width: KSpace.sm),
          CodeChip('KST-9WM2K'),
        ],
      ),
    );
  }
}
