import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/kasat_config.dart';
import '../../models/community_alert.dart';
import '../../theme/kasat_theme.dart';
import '../../widgets/k_field.dart';
import '../../widgets/kasat_button.dart';
import '../../widgets/panel.dart';
import '../../widgets/soft_backdrop.dart';

class ComposeAlertView extends StatefulWidget {
  const ComposeAlertView({super.key});

  @override
  State<ComposeAlertView> createState() => _ComposeAlertViewState();
}

class _ComposeAlertViewState extends State<ComposeAlertView> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  AlertKind _kind = AlertKind.safetyNotice;
  bool _busy = false;
  String? _result;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final scope = KasatScope.of(context);
    final country = scope.settings.countryCode;
    if (country == null) return;

    setState(() {
      _busy = true;
      _result = null;
    });

    final alert = await scope.alerts.submit(
      kind: _kind,
      title: _title.text,
      body: _body.text,
      countryCode: country,
      posterToken: scope.settings.posterToken(),
      verifiedSource: KasatConfig.placeholderVerifiedPoster,
    );

    if (!mounted) return;
    setState(() {
      _busy = false;
      _result = alert.visibility == AlertVisibility.live
          ? 'It is on the board.'
          : 'It is waiting for a person to read it first.';
    });
  }

  bool get _ready =>
      _title.text.trim().length >= 8 &&
      _body.text.trim().length >= 24 &&
      !_busy;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KC.canvas,
      body: SoftBackdrop(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(KSpace.sm, KSpace.sm, KSpace.xl, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                      color: KC.muted,
                    ),
                    Text('New notice', style: KType.serif(size: 22)),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(KSpace.xl),
                  children: [
                    const KNote(
                      title: 'This is not a chat',
                      body: 'A first look will read this for sense and for '
                          'unkindness. It cannot tell whether something really '
                          'happened. Unsure posts wait for a person.',
                      icon: Icons.menu_book_outlined,
                      color: KC.secondary,
                    ),
                    const SizedBox(height: KSpace.lg),
                    Text('What kind?', style: KType.label()),
                    const SizedBox(height: KSpace.sm),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final kind in AlertKind.values)
                          ChoiceChip(
                            label: Text(kind.label),
                            selected: _kind == kind,
                            onSelected: (_) => setState(() => _kind = kind),
                            selectedColor: KC.primarySoft,
                            labelStyle: KType.sans(
                              size: 13,
                              weight: FontWeight.w600,
                              color: _kind == kind ? KC.primary : KC.text,
                            ),
                            backgroundColor: KC.surface,
                            shape: RoundedRectangleBorder(
                              borderRadius: KRadius.rPill,
                              side: BorderSide(
                                color: _kind == kind ? KC.primary : KC.border,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: KSpace.lg),
                    const KFieldLabel('Short title'),
                    KTextField(
                      controller: _title,
                      hint: 'A sentence someone can scan',
                      maxLength: KasatConfig.alertTitleMax,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: KSpace.lg),
                    const KFieldLabel('What people need to know'),
                    KTextField(
                      controller: _body,
                      hint: 'Place, time, and what to do — not rumours.',
                      minLines: 5,
                      maxLines: 8,
                      maxLength: KasatConfig.alertBodyMax,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: KSpace.xl),
                    KButton(
                      label: 'Send for a first look',
                      busy: _busy,
                      onPressed: _ready ? _submit : null,
                    ),
                    if (_result != null) ...[
                      const SizedBox(height: KSpace.lg),
                      KNote(
                        title: 'Thank you',
                        body: _result!,
                        icon: Icons.favorite_outline_rounded,
                        color: KC.primary,
                      ),
                    ],
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
