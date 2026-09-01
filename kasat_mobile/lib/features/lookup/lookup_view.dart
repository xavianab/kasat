import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app.dart';
import '../../core/time_format.dart';
import '../../core/tracking_id.dart';
import '../../models/incident.dart';
import '../../theme/kasat_theme.dart';
import '../../widgets/k_field.dart';
import '../../widgets/kasat_button.dart';
import '../../widgets/mono_badge.dart';
import '../../widgets/panel.dart';
import '../../widgets/status_pill.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadLocalIds());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadLocalIds() async {
    final ids = await KasatScope.of(context).repository.localTrackingIds();
    if (!mounted) return;
    setState(() => _localIds = ids);
  }

  /// Entry point used by the shell after a successful submission.
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

    final incident = await KasatScope.of(context).repository.lookup(normalized);
    if (!mounted) return;

    setState(() {
      _searching = false;
      _resolvedId = incident == null ? null : normalized;
      _notFound = incident == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(KSpace.md, KSpace.md, KSpace.md, KSpace.xl),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        Text(
          'Case status',
          style: KType.sans(size: 19, weight: FontWeight.w800, tracking: -0.4),
        ),
        const SizedBox(height: 3),
        Text(
          'Enter the code you were given at submission. No other identifier will resolve a case.',
          style: KType.sans(size: 11.5, color: KC.muted, height: 1.35),
        ),
        const SizedBox(height: KSpace.md),
        KPanel(
          title: 'Tracking code',
          trailing: const MonoBadge('KST-XXXXX', size: 9, dense: true, color: KC.faint),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              KTextField(
                controller: _controller,
                hint: 'KST-8X9P2',
                mono: true,
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
                label: 'Resolve case',
                icon: Icons.travel_explore_rounded,
                busy: _searching,
                onPressed: _controller.text.trim().isEmpty ? null : _resolve,
              ),
              if (_localIds.isNotEmpty) ...[
                const KRule(),
                const KFieldLabel('Filed from this device'),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final id in _localIds.take(6))
                      GestureDetector(
                        onTap: () => loadTrackingId(id),
                        child: MonoBadge(id, color: KC.accent, filled: true, size: 10),
                      ),
                  ],
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

/// Keeps the tracking field uppercase as it is typed, so a code copied from a
/// note app matches without the survivor thinking about case.
class UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
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
    // Opened once per case, not once per build: calling watch() inside build
    // would tear down and re-establish the subscription on every frame, and a
    // status change landing in that gap would be dropped.
    _stream ??= KasatScope.of(context).repository.watch(widget.trackingId);
  }

  @override
  void didUpdateWidget(_LiveCase oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trackingId != widget.trackingId) {
      _stream = KasatScope.of(context).repository.watch(widget.trackingId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Incident?>(
      stream: _stream,
      builder: (context, snapshot) {
        final incident = snapshot.data;
        if (incident == null) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            KPanel(
              title: incident.trackingId,
              trailing: StatusPill(incident.status, live: true),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: KSpace.sm),
                    child: StatusTrack(incident.status),
                  ),
                  const KRule(height: KSpace.sm),
                  Text(
                    incident.status.blurb,
                    style: KType.sans(size: 12, color: KC.muted, height: 1.45),
                  ),
                  const KRule(height: KSpace.sm),
                  KMetaRow('Category', incident.category.label),
                  KMetaRow(
                    'Priority',
                    incident.priority.label,
                    valueColor: incident.priority.color,
                  ),
                  KMetaRow('Filed', TimeFormat.stamp(incident.submittedAt)),
                  KMetaRow('Last update', TimeFormat.elapsed(incident.updatedAt)),
                  KMetaRow('Station', incident.assignedStation ?? 'UNASSIGNED'),
                ],
              ),
            ),
            const SizedBox(height: KSpace.md),
            KPanel(
              title: 'Audit trail',
              trailing: MonoBadge(
                '${incident.history.length} EVENTS',
                size: 9,
                dense: true,
                color: KC.faint,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = incident.history.length - 1; i >= 0; i--)
                    _HistoryRow(
                      event: incident.history[i],
                      latest: i == incident.history.length - 1,
                    ),
                ],
              ),
            ),
            const SizedBox(height: KSpace.md),
            KPanel(
              title: 'Submitted statement',
              child: Text(
                incident.description,
                style: KType.sans(size: 12.5, color: KC.muted, height: 1.5),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.event, required this.latest});

  final StatusEvent event;
  final bool latest;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: latest ? event.status.color : Colors.transparent,
                border: Border.all(color: event.status.color, width: 1.4),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: KSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        event.status.label.toUpperCase(),
                        style: KType.mono(
                          size: 10.5,
                          weight: FontWeight.w700,
                          color: event.status.color,
                          tracking: 0.8,
                        ),
                      ),
                    ),
                    Text(
                      TimeFormat.stamp(event.at),
                      style: KType.mono(size: 9, color: KC.faint),
                    ),
                  ],
                ),
                if (event.note != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    event.note!,
                    style: KType.sans(size: 11.5, color: KC.muted, height: 1.4),
                  ),
                ],
                const SizedBox(height: 3),
                Text('ACTOR ${event.actor}', style: KType.mono(size: 8.5, color: KC.faint)),
              ],
            ),
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
    return Container(
      padding: const EdgeInsets.all(KSpace.md),
      decoration: BoxDecoration(
        color: KC.danger.withValues(alpha: 0.06),
        border: Border.all(color: KC.danger.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, size: 15, color: KC.danger),
          const SizedBox(width: KSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('NO CASE RESOLVED', style: KType.label(color: KC.danger)),
                const SizedBox(height: 4),
                Text(
                  'That code does not match a filed report. Codes are five '
                  'characters after the KST prefix and never contain 0, O, 1, '
                  'I, L or U.',
                  style: KType.sans(size: 11.5, color: KC.muted, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DemoHint extends StatelessWidget {
  const _DemoHint();

  @override
  Widget build(BuildContext context) {
    return KPanel(
      title: 'Reference cases',
      trailing: const MonoBadge('SEED DATA', size: 9, dense: true, color: KC.faint),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Two cases ship with the build so the lookup flow can be exercised '
            'before the dashboard is connected.',
            style: KType.sans(size: 11.5, color: KC.muted, height: 1.4),
          ),
          const SizedBox(height: KSpace.sm),
          const Row(
            children: [
              MonoBadge('KST-4RT7Q', color: KC.warn, filled: true, size: 10),
              SizedBox(width: 6),
              MonoBadge('KST-9WM2K', color: KC.accent, filled: true, size: 10),
            ],
          ),
        ],
      ),
    );
  }
}
