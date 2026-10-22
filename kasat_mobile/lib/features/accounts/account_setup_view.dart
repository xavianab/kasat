import 'package:flutter/material.dart';

import '../../app.dart';
import '../../theme/kasat_theme.dart';
import '../../widgets/k_field.dart';
import '../../widgets/kasat_button.dart';
import '../../widgets/panel.dart';
import '../more/more_scaffold.dart';
import 'identity_store.dart';

/// Optional on-device profile editor, reachable from Settings only.
///
/// Stored encrypted on-device in [IdentityStore] and NEVER synced to Supabase.
/// Only used to pre-fill her details if she explicitly chooses "Reveal my
/// identity to police" on a specific report.
class AccountSetupView extends StatefulWidget {
  const AccountSetupView({super.key, this.allowSkip = true});

  final bool allowSkip;

  @override
  State<AccountSetupView> createState() => _AccountSetupViewState();
}

class _AccountSetupViewState extends State<AccountSetupView> {
  final _name = TextEditingController();
  final _handle = TextEditingController();
  IdentityChannel _channel = IdentityChannel.phone;
  bool _hasExisting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final store = KasatScope.of(context).identity;
      final record = store.read();
      if (!mounted) return;
      if (record != null) {
        _name.text = record.displayName;
        _handle.text = record.handle;
        setState(() {
          _channel = record.channel;
          _hasExisting = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _handle.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final handle = _handle.text.trim();
    if (name.isEmpty || handle.isEmpty) return;
    await KasatScope.of(context).identity.save(
          IdentityRecord(displayName: name, channel: _channel, handle: handle),
        );
    if (mounted) Navigator.of(context).maybePop();
  }

  Future<void> _clear() async {
    await KasatScope.of(context).identity.clear();
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return MoreScaffold(
      title: 'Save my details (optional)',
      children: [
        const KNote(
          title: 'Optional — stays on your phone',
          icon: Icons.lock_outline_rounded,
          body: 'This is not an account or login. Your details are encrypted '
              'on this phone only so you can fill them in faster if you ever '
              'choose to reveal your identity to police on a report. They are '
              'never synced or sent automatically.',
        ),
        const SizedBox(height: KSpace.xl),
        const KFieldLabel('Your name', optional: true),
        KTextField(
          controller: _name,
          hint: 'e.g., Selamawit Tadesse',
        ),
        const SizedBox(height: KSpace.lg),
        const KFieldLabel('Preferred contact method', optional: true),
        Row(
          children: [
            ChoiceChip(
              label: const Text('Phone'),
              selected: _channel == IdentityChannel.phone,
              onSelected: (_) =>
                  setState(() => _channel = IdentityChannel.phone),
            ),
            const SizedBox(width: KSpace.sm),
            ChoiceChip(
              label: const Text('Email'),
              selected: _channel == IdentityChannel.email,
              onSelected: (_) =>
                  setState(() => _channel = IdentityChannel.email),
            ),
          ],
        ),
        const SizedBox(height: KSpace.md),
        KTextField(
          controller: _handle,
          hint: _channel == IdentityChannel.phone
              ? '+251 911 000 000'
              : 'name@example.com',
          keyboardType: _channel == IdentityChannel.phone
              ? TextInputType.phone
              : TextInputType.emailAddress,
        ),
        const SizedBox(height: KSpace.xl),
        KButton(
          label: 'Save encrypted on this phone',
          icon: Icons.lock_outline_rounded,
          onPressed: _save,
        ),
        if (_hasExisting) ...[
          const SizedBox(height: KSpace.sm),
          KButton(
            label: 'Remove saved details from this phone',
            kind: KButtonKind.soft,
            onPressed: _clear,
          ),
        ],
        if (widget.allowSkip) ...[
          const SizedBox(height: KSpace.sm),
          KButton(
            label: 'Cancel',
            kind: KButtonKind.ghost,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      ],
    );
  }
}
