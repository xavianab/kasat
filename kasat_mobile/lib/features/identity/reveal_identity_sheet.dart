import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app.dart';
import '../../models/incident.dart';
import '../../theme/kasat_theme.dart';
import '../../widgets/k_field.dart';
import '../../widgets/kasat_button.dart';
import '../../widgets/panel.dart';
import '../../widgets/soft_backdrop.dart';
import '../accounts/identity_store.dart';

/// Explicit confirmation screen for one-way self-identification on an existing
/// report ("Reveal my identity to police").
///
/// - Pre-fills from the encrypted on-device [IdentityStore] if she chose to save
///   her details in Settings.
/// - Clearly explains that revealing her identity is ONE-WAY (anonymous -> named)
///   and cannot be undone.
/// - Writes to the separate `report_identities` table linked by `report_id` so
///   `public.reports` stays structurally anonymous.
class RevealIdentityScreen extends StatefulWidget {
  const RevealIdentityScreen({
    super.key,
    required this.incident,
  });

  static const revealButtonKey = Key('reveal-identity-button');
  static const confirmButtonKey = Key('confirm-reveal-identity-button');

  final Incident incident;

  static Future<Incident?> open(BuildContext context, Incident incident) {
    return Navigator.of(context).push<Incident>(
      MaterialPageRoute<Incident>(
        fullscreenDialog: true,
        builder: (_) => RevealIdentityScreen(incident: incident),
      ),
    );
  }

  @override
  State<RevealIdentityScreen> createState() => _RevealIdentityScreenState();
}

class _RevealIdentityScreenState extends State<RevealIdentityScreen> {
  final _name = TextEditingController();
  final _handle = TextEditingController();
  final _safeNote = TextEditingController();
  IdentityChannel _channel = IdentityChannel.phone;
  bool _confirmedIrreversible = false;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final saved = KasatScope.of(context).identity.read();
      if (saved != null) {
        setState(() {
          _name.text = saved.displayName;
          _handle.text = saved.handle;
          _channel = saved.channel;
        });
      }
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _handle.dispose();
    _safeNote.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      !_submitting &&
      _confirmedIrreversible &&
      _name.text.trim().isNotEmpty &&
      _handle.text.trim().length >= 3;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final scope = KasatScope.of(context);
      final updated = await scope.repository.revealIdentity(
        widget.incident.trackingId,
        fullName: _name.text.trim(),
        channel: _channel.name,
        handle: _handle.text.trim(),
        safeNote: _safeNote.text.trim().isEmpty ? null : _safeNote.text.trim(),
      );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop(updated);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'Could not share your identity right now. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KC.canvas,
      body: SoftBackdrop(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  KSpace.sm,
                  KSpace.xs,
                  KSpace.lg,
                  0,
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, color: KC.muted),
                    ),
                    Text(
                      'Reveal my identity to police',
                      style: KType.serif(size: 20),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(KSpace.xl),
                  children: [
                    const KNote(
                      title: 'This cannot be undone (one-way only)',
                      icon: Icons.warning_amber_rounded,
                      color: KC.urgent,
                      body: 'Once you share your name and contact details on '
                          'this report, it moves permanently from anonymous '
                          'to named for the station handling your case. '
                          'You cannot make this report anonymous again. '
                          'Any other reports you file stay anonymous.',
                    ),
                    const SizedBox(height: KSpace.lg),
                    KPanel(
                      title: 'Details to share on ${widget.incident.trackingId}',
                      subtitle:
                          'Stored in a separate identity record linked only to this report.',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const KFieldLabel('Your name'),
                          KTextField(
                            controller: _name,
                            hint: 'e.g., Selamawit Tadesse',
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: KSpace.lg),
                          const KFieldLabel('How police may contact you'),
                          Row(
                            children: [
                              ChoiceChip(
                                label: const Text('Phone number'),
                                selected: _channel == IdentityChannel.phone,
                                onSelected: (_) => setState(
                                  () => _channel = IdentityChannel.phone,
                                ),
                              ),
                              const SizedBox(width: KSpace.sm),
                              ChoiceChip(
                                label: const Text('Email'),
                                selected: _channel == IdentityChannel.email,
                                onSelected: (_) => setState(
                                  () => _channel = IdentityChannel.email,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: KSpace.md),
                          KTextField(
                            controller: _handle,
                            hint: _channel == IdentityChannel.phone
                                ? 'e.g., +251 911 000 000'
                                : 'e.g., name@example.com',
                            keyboardType: _channel == IdentityChannel.phone
                                ? TextInputType.phone
                                : TextInputType.emailAddress,
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: KSpace.lg),
                          const KFieldLabel(
                            'When is it safe to call or message you?',
                            optional: true,
                          ),
                          KTextField(
                            controller: _safeNote,
                            hint: 'e.g., Only call between 9am and 4pm on weekdays',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: KSpace.md),
                    GestureDetector(
                      onTap: () => setState(
                        () => _confirmedIrreversible = !_confirmedIrreversible,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(KSpace.md),
                        decoration: BoxDecoration(
                          color: _confirmedIrreversible
                              ? KC.primarySoft
                              : KC.surface,
                          borderRadius: KRadius.rMd,
                          border: Border.all(
                            color: _confirmedIrreversible
                                ? KC.primary
                                : KC.borderStrong,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Checkbox(
                              value: _confirmedIrreversible,
                              activeColor: KC.primary,
                              onChanged: (v) => setState(
                                () => _confirmedIrreversible = v ?? false,
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  'I understand that revealing my identity on '
                                  'case ${widget.incident.trackingId} is '
                                  'permanent and cannot be undone.',
                                  style: KType.sans(
                                    size: 13.5,
                                    weight: FontWeight.w600,
                                    color: KC.text,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: KSpace.md),
                      Text(
                        _error!,
                        style: KType.sans(size: 13.5, color: KC.urgent),
                      ),
                    ],
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    KButton(
                      key: RevealIdentityScreen.confirmButtonKey,
                      label: 'Confirm & reveal my identity to police',
                      icon: Icons.badge_outlined,
                      busy: _submitting,
                      onPressed: _canSubmit ? _submit : null,
                    ),
                    const SizedBox(height: KSpace.xs),
                    KButton(
                      label: 'Keep this report anonymous',
                      kind: KButtonKind.ghost,
                      compact: true,
                      onPressed: () => Navigator.of(context).pop(),
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
