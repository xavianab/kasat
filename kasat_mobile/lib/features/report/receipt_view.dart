import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app.dart';
import '../../core/time_format.dart';
import '../../models/country.dart';
import '../../models/incident.dart';
import '../../models/incident_status.dart';
import '../../theme/kasat_theme.dart';
import '../../widgets/kasat_button.dart';
import '../../widgets/panel.dart';
import '../../widgets/soft_backdrop.dart';
import '../../widgets/status_pill.dart';
import '../identity/reveal_identity_sheet.dart';
import '../lock/pin_setup_sheet.dart';

/// Post-save confirmation. The tracking code is the payload of this screen.
///
/// Issue 3 safety rule:
/// 1. Shows the tracking code immediately after submission BEFORE any PIN is set.
/// 2. Insists she write the tracking code down (`wroteDownCheckboxKey`) before
///    setting a PIN or leaving the screen.
class ReceiptView extends StatefulWidget {
  const ReceiptView({super.key, required this.incident, required this.onTrack});

  static const wroteDownConfirmKey = Key('confirm-wrote-tracking-code');
  static const setPinAfterCodeKey = Key('set-pin-after-code-button');

  final Incident incident;
  final VoidCallback onTrack;

  @override
  State<ReceiptView> createState() => _ReceiptViewState();
}

class _ReceiptViewState extends State<ReceiptView> {
  late Incident _incident;
  bool _sending = false;
  bool _wroteCodeDown = false;

  @override
  void initState() {
    super.initState();
    _incident = widget.incident;
  }

  bool get _isDraft =>
      _incident.status == IncidentStatus.draft ||
      _incident.status == IncidentStatus.queued;

  Future<void> _send() async {
    setState(() => _sending = true);
    final updated = await KasatScope.of(context)
        .repository
        .sendToPolice(_incident.trackingId);
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (updated != null) _incident = updated;
    });
  }

  Future<void> _revealIdentity() async {
    final updated = await RevealIdentityScreen.open(context, _incident);
    if (updated != null && mounted) {
      setState(() => _incident = updated);
    }
  }

  Future<void> _promptPinAfterWritingCode() async {
    final scope = KasatScope.of(context);
    if (scope.settings.hasPin) return;
    await PinGuard.ensurePinForSaving(
      context,
      reason:
          'Now that you have written down your tracking code (${_incident.trackingId}), set a 6-digit PIN to lock the saved-reports list on this phone.',
    );
    if (mounted) setState(() {});
  }

  Future<void> _finish({required bool track}) async {
    if (!_wroteCodeDown) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: KC.urgent,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(KSpace.lg),
          shape: const RoundedRectangleBorder(borderRadius: KRadius.rMd),
          content: Text(
            'Please write down your tracking code (${_incident.trackingId}) and confirm first.',
            style: KType.sans(size: 13.5, color: Colors.white),
          ),
        ),
      );
      return;
    }
    final scope = KasatScope.of(context);
    if (!scope.settings.hasPin) {
      await _promptPinAfterWritingCode();
      if (!mounted) return;
    }
    Navigator.of(context).pop();
    if (track) widget.onTrack();
  }

  @override
  Widget build(BuildContext context) {
    final scope = KasatScope.of(context);
    final country = countryByCode(_incident.countryCode);
    final queued = _incident.status == IncidentStatus.queued;
    final draft = _incident.status == IncidentStatus.draft;
    final serverSha = _incident.evidenceSha256;
    final clientSha = _incident.clientEvidenceSha256 ??
        (_incident.attachments.isNotEmpty
            ? _incident.attachments.first.sha256
            : null);

    return Scaffold(
      backgroundColor: KC.canvas,
      body: SoftBackdrop(
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    KSpace.xl,
                    KSpace.xl,
                    KSpace.xl,
                    KSpace.lg,
                  ),
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _isDraft ? KC.primarySoft : KC.calmSoft,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _isDraft
                                ? Icons.edit_outlined
                                : Icons.check_rounded,
                            size: 19,
                            color: _isDraft ? KC.primary : KC.calm,
                          ),
                        ),
                        const SizedBox(width: KSpace.md),
                        Expanded(
                          child: Text(
                            queued
                                ? 'Saved on this phone'
                                : draft
                                    ? 'Saved as a draft'
                                    : 'It has been sent',
                            style: KType.serif(size: 24),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: KSpace.md),
                    Text(
                      queued
                          ? 'There was no connection, so nothing left yet. It will send on its own when this phone is back online.'
                          : draft
                              ? 'Police cannot see this yet. Send it only when you are ready.'
                              : _incident.identityRevealed
                                  ? 'Thank you. Your report and the contact details you chose to reveal are with the station.'
                                  : 'Thank you. Nothing about who you are went with it.',
                      style: KType.sans(
                        size: 14.5,
                        color: KC.muted,
                        height: 1.55,
                      ),
                    ),
                    const SizedBox(height: KSpace.xl),
                    _TrackingCard(trackingId: _incident.trackingId),
                    const SizedBox(height: KSpace.md),
                    const KNote(
                      title: 'Step 1 — Write this tracking code down now',
                      icon: Icons.edit_note_rounded,
                      color: KC.secondary,
                      body: 'Your tracking code is your credential. You can always '
                          'look up your case with this code even without a PIN or '
                          'if you forget your PIN. Write it down on paper before '
                          'setting a PIN or leaving this screen.',
                    ),
                    const SizedBox(height: KSpace.sm),
                    GestureDetector(
                      key: ReceiptView.wroteDownConfirmKey,
                      onTap: () =>
                          setState(() => _wroteCodeDown = !_wroteCodeDown),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: KSpace.md,
                          vertical: KSpace.md,
                        ),
                        decoration: BoxDecoration(
                          color: _wroteCodeDown ? KC.calmSoft : KC.surface,
                          borderRadius: KRadius.rMd,
                          border: Border.all(
                            color: _wroteCodeDown ? KC.calm : KC.primary,
                            width: 1.4,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _wroteCodeDown
                                  ? Icons.check_box_rounded
                                  : Icons.check_box_outline_blank_rounded,
                              color: _wroteCodeDown ? KC.calm : KC.primary,
                              size: 22,
                            ),
                            const SizedBox(width: KSpace.sm),
                            Expanded(
                              child: Text(
                                'I have written down ${_incident.trackingId} in a safe place',
                                style: KType.sans(
                                  size: 13.5,
                                  weight: FontWeight.w600,
                                  color: KC.text,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_wroteCodeDown && !scope.settings.hasPin) ...[
                      const SizedBox(height: KSpace.md),
                      KButton(
                        key: ReceiptView.setPinAfterCodeKey,
                        label: 'Step 2 — Set 6-digit PIN for saved history',
                        kind: KButtonKind.secondary,
                        icon: Icons.lock_outline_rounded,
                        compact: true,
                        onPressed: _promptPinAfterWritingCode,
                      ),
                    ],
                    const SizedBox(height: KSpace.md),
                    KPanel(
                      title: draft ? 'What was saved' : 'What was sent',
                      trailing: StatusPill(_incident.status),
                      child: Column(
                        children: [
                          KMetaRow('Kind', _incident.category.label),
                          KMetaRow(
                            'Priority',
                            _incident.priority.label,
                            valueColor: _incident.priority.color,
                          ),
                          KMetaRow(
                            'Country',
                            country?.name ?? _incident.countryCode,
                          ),
                          KMetaRow(
                            'Saved',
                            TimeFormat.stamp(_incident.submittedAt),
                          ),
                          KMetaRow(
                            'Photos',
                            _incident.attachments.isEmpty
                                ? 'None'
                                : '${_incident.attachments.length}, EXIF stripped + SHA-256 verified',
                          ),
                          if (serverSha != null)
                            KMetaRow(
                              'Server SHA-256',
                              '${serverSha.substring(0, 16)}… (authoritative)',
                              valueColor: KC.calm,
                            )
                          else if (clientSha != null)
                            KMetaRow(
                              'Transport SHA-256',
                              '${clientSha.substring(0, 16)}… (pending server verify)',
                            ),
                          KMetaRow(
                            'Place',
                            _incident.location?.displayLabel ?? 'Not given',
                          ),
                          KMetaRow(
                            'Your name',
                            _incident.identityRevealed
                                ? (_incident.revealedName ?? 'Shared with police')
                                : 'Never asked',
                            valueColor: _incident.identityRevealed
                                ? KC.primary
                                : KC.calm,
                          ),
                        ],
                      ),
                    ),
                    if (draft) ...[
                      const SizedBox(height: KSpace.lg),
                      KButton(
                        label: 'Send to police',
                        icon: Icons.send_rounded,
                        busy: _sending,
                        onPressed: _sending ? null : _send,
                      ),
                    ],
                    const SizedBox(height: KSpace.md),
                    if (!_incident.identityRevealed)
                      KButton(
                        label: 'Reveal my identity to police (optional)',
                        kind: KButtonKind.ghost,
                        icon: Icons.badge_outlined,
                        compact: true,
                        onPressed: _revealIdentity,
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(
                  KSpace.lg,
                  KSpace.md,
                  KSpace.lg,
                  KSpace.sm,
                ),
                decoration: const BoxDecoration(
                  color: KC.surface,
                  border: Border(top: BorderSide(color: KC.border)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: KButton(
                        label: 'Done',
                        kind: KButtonKind.soft,
                        onPressed: () => _finish(track: false),
                      ),
                    ),
                    const SizedBox(width: KSpace.sm),
                    Expanded(
                      flex: 2,
                      child: KButton(
                        label: 'Follow my case',
                        icon: Icons.schedule_outlined,
                        onPressed: () => _finish(track: true),
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

class _TrackingCard extends StatelessWidget {
  const _TrackingCard({required this.trackingId});

  final String trackingId;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(KSpace.xl),
      decoration: BoxDecoration(
        color: KC.surface,
        border: Border.all(color: KC.primary, width: 1.6),
        borderRadius: KRadius.rXl,
        boxShadow: KShadow.card,
      ),
      child: Column(
        children: [
          Text(
            'Your code',
            style:
                KType.sans(size: 13, weight: FontWeight.w600, color: KC.muted),
          ),
          const SizedBox(height: KSpace.md),
          FittedBox(
            child: Text(
              trackingId,
              style: KType.code(
                size: 36,
                weight: FontWeight.w700,
                color: KC.primary,
              ),
            ),
          ),
          const SizedBox(height: KSpace.lg),
          KButton(
            label: 'Copy',
            kind: KButtonKind.secondary,
            icon: Icons.content_copy_rounded,
            compact: true,
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: trackingId));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: KC.text,
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.all(KSpace.lg),
                  shape: const RoundedRectangleBorder(borderRadius: KRadius.rMd),
                  duration: const Duration(seconds: 2),
                  content: Text(
                    'Copied',
                    style: KType.sans(size: 14, color: Colors.white),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
