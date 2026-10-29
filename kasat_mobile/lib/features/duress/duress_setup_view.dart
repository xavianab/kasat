import 'package:flutter/material.dart';

import '../../app.dart';
import '../../theme/kasat_theme.dart';
import '../../widgets/k_field.dart';
import '../../widgets/kasat_button.dart';
import '../../widgets/panel.dart';
import '../more/more_scaffold.dart';
import 'duress_store.dart';

class DuressSetupView extends StatefulWidget {
  const DuressSetupView({super.key});

  @override
  State<DuressSetupView> createState() => _DuressSetupViewState();
}

class _DuressSetupViewState extends State<DuressSetupView> {
  final _name = TextEditingController();
  final _phone = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final contact = KasatScope.of(context).duress.read();
      if (contact == null || !mounted) return;
      _name.text = contact.name;
      _phone.text = contact.phone;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final i18n = KasatScope.of(context).i18n;
    final saved = KasatScope.of(context).duress.hasContact;
    return MoreScaffold(
      title: i18n.t('duress.title'),
      children: [
        Text(i18n.t('duress.blurb'), style: KType.sans(size: 14.5, color: KC.muted, height: 1.55)),
        const SizedBox(height: KSpace.lg),
        // STUB: locked-screen / background shake is Phase 2. See PHASE2_ROADMAP.md.
        KNote(
          title: i18n.t('duress.title'),
          icon: Icons.info_outline_rounded,
          body: i18n.t('duress.phase2'),
        ),
        const SizedBox(height: KSpace.xl),
        KFieldLabel(i18n.t('duress.name')),
        KTextField(controller: _name),
        const SizedBox(height: KSpace.lg),
        KFieldLabel(i18n.t('duress.phone')),
        KTextField(controller: _phone, keyboardType: TextInputType.phone),
        const SizedBox(height: KSpace.xl),
        KButton(
          label: i18n.t('duress.save'),
          onPressed: () async {
            if (_name.text.trim().isEmpty || _phone.text.trim().isEmpty) return;
            await KasatScope.of(context).duress.save(
                  TrustedContact(name: _name.text, phone: _phone.text),
                );
            if (mounted) setState(() {});
          },
        ),
        if (saved) ...[
          const SizedBox(height: KSpace.sm),
          KButton(
            label: i18n.t('duress.remove'),
            kind: KButtonKind.soft,
            onPressed: () async {
              await KasatScope.of(context).duress.clear();
              _name.clear();
              _phone.clear();
              setState(() {});
            },
          ),
        ],
      ],
    );
  }
}
