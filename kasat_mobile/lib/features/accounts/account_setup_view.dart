import 'package:flutter/material.dart';

import '../../app.dart';
import '../../theme/kasat_theme.dart';
import '../../widgets/k_field.dart';
import '../../widgets/kasat_button.dart';
import '../../widgets/panel.dart';
import '../more/more_scaffold.dart';
import 'identity_store.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final record = KasatScope.of(context).identity.read();
      if (record == null || !mounted) return;
      _name.text = record.displayName;
      _handle.text = record.handle;
      setState(() => _channel = record.channel);
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

  @override
  Widget build(BuildContext context) {
    final i18n = KasatScope.of(context).i18n;
    return MoreScaffold(
      title: i18n.t('account.title'),
      children: [
        KNote(
          title: i18n.t('account.title'),
          icon: Icons.lock_outline_rounded,
          body: i18n.t('account.blurb'),
        ),
        const SizedBox(height: KSpace.xl),
        KFieldLabel(i18n.t('account.display')),
        KTextField(controller: _name, hint: i18n.t('account.displayHint')),
        const SizedBox(height: KSpace.lg),
        KFieldLabel(i18n.t('account.channel')),
        Row(
          children: [
            ChoiceChip(
              label: Text(i18n.t('account.phone')),
              selected: _channel == IdentityChannel.phone,
              onSelected: (_) => setState(() => _channel = IdentityChannel.phone),
            ),
            const SizedBox(width: KSpace.sm),
            ChoiceChip(
              label: Text(i18n.t('account.email')),
              selected: _channel == IdentityChannel.email,
              onSelected: (_) => setState(() => _channel = IdentityChannel.email),
            ),
          ],
        ),
        const SizedBox(height: KSpace.md),
        KTextField(
          controller: _handle,
          hint: i18n.t('account.handleHint'),
          keyboardType: _channel == IdentityChannel.phone
              ? TextInputType.phone
              : TextInputType.emailAddress,
        ),
        const SizedBox(height: KSpace.xl),
        KButton(label: i18n.t('account.save'), onPressed: _save),
        if (widget.allowSkip) ...[
          const SizedBox(height: KSpace.sm),
          KButton(
            label: i18n.t('account.skip'),
            kind: KButtonKind.ghost,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      ],
    );
  }
}
