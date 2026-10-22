import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app.dart';
import '../../core/time_format.dart';
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
  final _controller = TextEditingController();

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
      padding:
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
        if (_resolvedId == null && !_notFound && !_searching) const _DemoHint(),
      ],
    );
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

  final String trackingId;

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
                  const KRule(height: KSpace.lg),
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
