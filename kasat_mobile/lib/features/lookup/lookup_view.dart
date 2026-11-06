import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app.dart';
import '../../core/kasat_config.dart';
import '../../core/time_format.dart';
import '../../core/tracking_id.dart';
import '../../core/update_notifier.dart';
import '../../data/remote_reports_client.dart';
import '../../models/incident.dart';
import '../../models/incident_status.dart';
import '../../theme/kasat_theme.dart';
import '../../widgets/k_field.dart';
import '../../widgets/kasat_button.dart';
import '../../widgets/panel.dart';
import '../../widgets/soft_badge.dart';
import '../../widgets/status_pill.dart';
import '../identity/reveal_identity_sheet.dart';
import '../lock/pin_setup_sheet.dart';

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

class LookupView extends StatefulWidget {
  const LookupView({super.key});

  @override
  State<LookupView> createState() => LookupViewState();
}

class LookupViewState extends State<LookupView> {
  final _controller = TextEditingController();

  final _messages = _MessageRefresh();
  String? _resolvedId;
  Incident? _resolvedIncident;
  Stream<Incident?>? _stream;
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
        _resolvedIncident = null;
        _stream = null;
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
  /// Do NOT gate tracking-code lookup behind the PIN. A valid tracking code is
  /// itself the credential; the PIN protects only the saved-history list on
  /// this device.
  Future<void> loadTrackingId(String trackingId) async {
    _controller.text = trackingId;
    await _loadLocalIds();
    await _resolve();
  }

  void _watchIncident(Incident incident) {
    final scope = KasatScope.of(context);
    setState(() {
      _resolvedId = incident.trackingId;
      _resolvedIncident = incident;
      _stream = scope.repository.watch(incident.trackingId);
    });
  }

  Future<void> _resolve() async {
    final normalized = TrackingId.normalize(_controller.text);
    FocusScope.of(context).unfocus();

    if (normalized == null) {
      setState(() {
        _resolvedId = null;
        _resolvedIncident = null;
        _stream = null;
        _notFound = true;
      });
      return;
    }

    setState(() {
      _searching = true;
      _notFound = false;
      _resolvedId = null;
      _resolvedIncident = null;
      _stream = null;
    });

    final scope = KasatScope.of(context);
    final incident = await scope.repository.lookup(normalized);
    if (!mounted) return;

    setState(() {
      _searching = false;
      _resolvedId = incident == null ? null : normalized;
      _resolvedIncident = incident;
      _stream = incident == null ? null : scope.repository.watch(normalized);
      _notFound = incident == null;
    });
  }

  static bool _isWithPolice(Incident incident) {
    return incident.status == IncidentStatus.sent ||
        incident.status == IncidentStatus.underReview ||
        incident.status == IncidentStatus.resolved;
  }

  @override
  Widget build(BuildContext context) {
    final scope = KasatScope.of(context);
    final unlocked = scope.settings.hasPin && scope.isPinSessionUnlocked;

    return StreamBuilder<Incident?>(
      stream: _stream,
      builder: (context, snapshot) {
        final incident = _resolvedId == null
            ? null
            : (snapshot.data ?? _resolvedIncident);
        final showReplyBar = incident != null && _isWithPolice(incident);

        return Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: _messages.call,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    KSpace.lg,
                    KSpace.sm,
                    KSpace.lg,
                    KSpace.xxl,
                  ),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            'Enter the code from your report. Your code works anytime without a PIN.',
                            style: KType.sans(
                              size: 14,
                              color: KC.muted,
                              height: 1.45,
                            ),
                          ),
                        ),
                        if (unlocked) ...[
                          const SizedBox(width: KSpace.sm),
                          Flexible(
                            child: GestureDetector(
                              onTap: () => scope.lockPinSession(),
                              child: SoftBadge(
                                'Lock history',
                                icon: Icons.lock_outline_rounded,
                                color: KC.muted,
                                dense: true,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: KSpace.lg),
                    Text(
                      'Your code',
                      style: KType.sans(size: 16, weight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Type your KST-XXXXX code directly. No PIN is required.',
                      style: KType.sans(
                        size: 13,
                        color: KC.muted,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: KSpace.sm),
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
                    const SizedBox(height: KSpace.sm),
                    KButton(
                      label: 'Look it up',
                      icon: Icons.search_rounded,
                      busy: _searching,
                      onPressed:
                          _controller.text.trim().isEmpty ? null : _resolve,
                    ),
                    if (_localIds.isNotEmpty) ...[
                      const KRule(height: KSpace.lg),
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
                        _PinGateSection(
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
                    const SizedBox(height: KSpace.lg),
                    if (_notFound) const _NotFoundCard(),
                    if (incident != null)
                      _LiveCase(
                        incident: incident,
                        messages: _messages,
                        onUpdatedIncident: _watchIncident,
                      ),
                    if (_resolvedId == null && !_notFound && !_searching)
                      const _DemoHint(),
                  ],
                ),
              ),
            ),
            if (showReplyBar)
              _CaseReplyBar(
                accessSecret: incident.accessSecret ?? '',
                messages: _messages,
              ),
          ],
        );
      },
    );
  }
}

class _PinGateSection extends StatelessWidget {
  const _PinGateSection({
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          hasPin
              ? 'Saved history ($savedCount on this phone) is locked with your 6-digit PIN. You can also type your written tracking code above without a PIN.'
              : 'Protect your saved history ($savedCount on this phone) with a 6-digit PIN so nobody else who picks up this phone can see it.',
          style: KType.sans(size: 13, color: KC.muted, height: 1.45),
        ),
        const SizedBox(height: KSpace.sm),
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
    );
  }
}

/// Keeps the tracking field uppercase as it is typed.
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
  const _LiveCase({
    required this.incident,
    required this.messages,
    required this.onUpdatedIncident,
  });

  final Incident incident;
  final _MessageRefresh messages;
  final ValueChanged<Incident> onUpdatedIncident;

  @override
  State<_LiveCase> createState() => _LiveCaseState();
}

class _LiveCaseState extends State<_LiveCase> {
  bool _sendingReport = false;
  String? _sendError;

  Future<void> _sendReport() async {
    setState(() {
      _sendingReport = true;
      _sendError = null;
    });
    final updated = await KasatScope.of(context)
        .repository
        .sendToPolice(widget.incident.trackingId);
    if (!mounted) return;
    setState(() {
      _sendingReport = false;
      _sendError = updated == null
          ? 'That did not send. Pull down to try again.'
          : null;
    });
    if (updated != null) {
      widget.onUpdatedIncident(updated);
    }
  }

  Future<void> _openReveal(Incident incident) async {
    final updated = await RevealIdentityScreen.open(context, incident);
    if (updated != null && mounted) {
      widget.onUpdatedIncident(updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final incident = widget.incident;
    final withPolice = LookupViewState._isWithPolice(incident);
    final secret = incident.accessSecret ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const KRule(height: KSpace.lg),
        Wrap(
          spacing: KSpace.sm,
          runSpacing: KSpace.xs,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Your case',
              style: KType.sans(size: 16, weight: FontWeight.w600),
            ),
            StatusPill(incident.status, live: true),
          ],
        ),
        const SizedBox(height: KSpace.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: CodeChip(incident.trackingId, size: 15),
        ),
        const SizedBox(height: KSpace.md),
        if (!withPolice) ...[
          Text(
            'Not sent yet. Police cannot see this until you send it.',
            style: KType.sans(size: 15, height: 1.45),
          ),
          const SizedBox(height: KSpace.md),
          KButton(
            label: 'Send report',
            icon: Icons.send_rounded,
            busy: _sendingReport,
            onPressed: _sendingReport ? null : _sendReport,
          ),
          if (_sendError != null) ...[
            const SizedBox(height: KSpace.sm),
            Text(
              _sendError!,
              style: KType.sans(size: 13, color: KC.urgent, height: 1.4),
            ),
          ],
          const SizedBox(height: KSpace.sm),
          Text(
            incident.status.blurb,
            style: KType.sans(size: 13.5, color: KC.muted, height: 1.5),
          ),
        ] else ...[
          StatusTrack(incident.status),
          const SizedBox(height: KSpace.sm),
          if (secret.isNotEmpty &&
              KasatConfig.supabaseUrl.isNotEmpty &&
              KasatConfig.supabaseAnonKey.isNotEmpty)
            _CaseProgress(
              accessSecret: secret,
              messages: widget.messages,
            ),
          Text(
            incident.status.blurb,
            style: KType.sans(size: 13.5, color: KC.muted, height: 1.5),
          ),
        ],
        const KRule(height: KSpace.lg),
        Text(
          'What has happened so far',
          style: KType.sans(size: 16, weight: FontWeight.w600),
        ),
        const SizedBox(height: KSpace.sm),
        for (var i = incident.history.length - 1; i >= 0; i--)
          _HistoryRow(
            event: incident.history[i],
            latest: i == incident.history.length - 1,
            last: i == 0,
          ),
        if (withPolice) ...[
          const KRule(height: KSpace.lg),
          _CaseRepliesThread(
            accessSecret: secret,
            messages: widget.messages,
          ),
        ],
        const KRule(height: KSpace.lg),
        Text(
          'Details',
          style: KType.sans(size: 16, weight: FontWeight.w600),
        ),
        const SizedBox(height: KSpace.xs),
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
        const KRule(height: KSpace.lg),
        Text(
          'What you wrote',
          style: KType.sans(size: 16, weight: FontWeight.w600),
        ),
        const SizedBox(height: KSpace.xs),
        Text(
          incident.description,
          style: KType.sans(size: 13.5, color: KC.muted, height: 1.55),
        ),
        const KRule(height: KSpace.lg),
        Text(
          'Identity on this report',
          style: KType.sans(size: 16, weight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          incident.identityRevealed
              ? 'Named. Shared with police.'
              : 'Anonymous. No name or phone attached.',
          style: KType.sans(size: 13, color: KC.muted, height: 1.4),
        ),
        const SizedBox(height: KSpace.xs),
        if (incident.identityRevealed)
          Text(
            'You shared your identity with police for this report${incident.revealedName != null ? ' (${incident.revealedName})' : ''}. This is permanent and cannot be undone.',
            style: KType.sans(size: 13.5, color: KC.muted, height: 1.5),
          )
        else ...[
          Text(
            'This report is anonymous. You can share your name and contact details on this case if you want police to reach you. This is permanent.',
            style: KType.sans(size: 13.5, color: KC.muted, height: 1.5),
          ),
          const SizedBox(height: KSpace.sm),
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
                Wrap(
                  spacing: KSpace.sm,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      event.status.label,
                      style: KType.sans(
                        size: 13.5,
                        weight: FontWeight.w600,
                        color: event.status.color,
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

class _CaseProgress extends StatefulWidget {
  const _CaseProgress({required this.accessSecret, required this.messages});

  final String accessSecret;
  final _MessageRefresh messages;

  @override
  State<_CaseProgress> createState() => _CaseProgressState();
}

class _CaseProgressState extends State<_CaseProgress>
    with WidgetsBindingObserver {
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
      return Text(
        'Checking progress…',
        style: KType.sans(size: 13.5, color: KC.muted),
      );
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
          Text(
            _error!,
            style: KType.sans(size: 13, color: KC.urgent, height: 1.4),
          ),
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
                    border: Border.all(
                      color: step.reached ? color : KC.borderStrong,
                      width: 2,
                    ),
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

class _CaseRepliesThread extends StatefulWidget {
  const _CaseRepliesThread({
    required this.accessSecret,
    required this.messages,
  });

  final String accessSecret;
  final _MessageRefresh messages;

  @override
  State<_CaseRepliesThread> createState() => _CaseRepliesThreadState();
}

class _CaseRepliesThreadState extends State<_CaseRepliesThread>
    with WidgetsBindingObserver {
  final _remote = RemoteReportsClient();
  List<SurvivorReply> _rows = const [];
  Set<String> _seenOfficer = const {};
  bool _hasBaseline = false;
  bool _foreground = true;
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
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => reload());
    reload();
  }

  @override
  void didUpdateWidget(_CaseRepliesThread oldWidget) {
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
    final foreground = state == AppLifecycleState.resumed;
    _foreground = foreground;
    if (foreground) reload();
  }

  String _officerKey(SurvivorReply row) =>
      '${row.createdAt.toUtc().toIso8601String()}|${row.body}';

  Future<void> reload() async {
    if (widget.accessSecret.isEmpty) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Couldn\'t load messages. Pull down to try again.';
      });
      return;
    }
    try {
      final rows = await _remote.listSurvivorReplies(widget.accessSecret);
      if (!mounted) return;
      final officer = rows
          .where((row) => row.sender == 'officer')
          .map(_officerKey)
          .toSet();
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
        _error = 'Couldn\'t load messages. Pull down to try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Messages',
          style: KType.sans(size: 16, weight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          'Replies from the station, and your answers.',
          style: KType.sans(size: 13, color: KC.muted, height: 1.4),
        ),
        const SizedBox(height: KSpace.sm),
        if (_loading && _rows.isEmpty)
          Text(
            'Loading messages…',
            style: KType.sans(size: 13.5, color: KC.muted),
          )
        else if (_error != null && _rows.isEmpty)
          Text(
            _error!,
            style: KType.sans(size: 13.5, color: KC.urgent, height: 1.45),
          )
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
        if (_error != null && _rows.isNotEmpty) ...[
          const SizedBox(height: KSpace.xs),
          Text(
            _error!,
            style: KType.sans(size: 13, color: KC.urgent, height: 1.4),
          ),
        ],
      ],
    );
  }
}

class _CaseReplyBar extends StatefulWidget {
  const _CaseReplyBar({
    required this.accessSecret,
    required this.messages,
  });

  final String accessSecret;
  final _MessageRefresh messages;

  @override
  State<_CaseReplyBar> createState() => _CaseReplyBarState();
}

class _CaseReplyBarState extends State<_CaseReplyBar> {
  final _reply = TextEditingController();
  final _remote = RemoteReportsClient();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
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
      await widget.messages.call();
      if (!mounted) return;
      setState(() => _sending = false);
    } catch (error) {
      if (!mounted) return;
      final tooMany = error.toString().contains('too many messages');
      setState(() {
        _sending = false;
        _error = tooMany
            ? 'That is enough messages for now. Try again in a little while.'
            : 'Couldn\'t send your message. Pull down to try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        KSpace.lg,
        KSpace.sm,
        KSpace.lg,
        KSpace.sm,
      ),
      decoration: BoxDecoration(
        color: KC.surface,
        border: Border(top: BorderSide(color: KC.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[
            Text(
              _error!,
              style: KType.sans(size: 12.5, color: KC.urgent, height: 1.35),
            ),
            const SizedBox(height: KSpace.xs),
          ],
          Row(
            children: [
              Expanded(
                child: KTextField(
                  controller: _reply,
                  hint: 'Write a reply',
                  maxLines: 2,
                ),
              ),
              const SizedBox(width: KSpace.sm),
              KButton(
                label: 'Send',
                icon: Icons.send_rounded,
                expand: false,
                compact: true,
                busy: _sending,
                onPressed: _sending ? null : _send,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NotFoundCard extends StatelessWidget {
  const _NotFoundCard();

  @override
  Widget build(BuildContext context) {
    return KNote(
      title: 'No case with that code',
      icon: Icons.help_outline_rounded,
      color: KC.secondary,
      body: 'Codes have five characters after KST. Letters O, I, L, and U, and '
          'digits 0 and 1 are not used. Check the code and try again.',
    );
  }
}

class _DemoHint extends StatelessWidget {
  const _DemoHint();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Example cases',
          style: KType.sans(size: 16, weight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          'Included with this build so you can see how tracking looks.',
          style: KType.sans(size: 13, color: KC.muted, height: 1.4),
        ),
        const SizedBox(height: KSpace.sm),
        const Wrap(
          spacing: KSpace.sm,
          runSpacing: KSpace.sm,
          children: [
            CodeChip('KST-4RT7Q'),
            CodeChip('KST-9WM2K'),
          ],
        ),
      ],
    );
  }
}
