import 'package:flutter/material.dart';

import '../../app.dart';
import '../../models/community_alert.dart';
import '../../theme/kasat_theme.dart';
import '../../widgets/k_field.dart';
import '../../widgets/kasat_button.dart';

Future<void> showTipSheet(BuildContext context, {required CommunityAlert alert}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: KC.surface,
    barrierColor: const Color(0x663D2A2A),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => _TipSheet(alert: alert),
  );
}

class _TipSheet extends StatefulWidget {
  const _TipSheet({required this.alert});

  final CommunityAlert alert;

  @override
  State<_TipSheet> createState() => _TipSheetState();
}

class _TipSheetState extends State<_TipSheet> {
  final _body = TextEditingController();
  bool _sent = false;

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(KSpace.xl, KSpace.lg, KSpace.xl, padding + KSpace.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('A private note', style: KType.serif(size: 22)),
          const SizedBox(height: KSpace.sm),
          Text(
            'This goes only to the person who posted “${widget.alert.title}”. '
            'Nobody else on the board will see it.',
            style: KType.sans(size: 14, color: KC.muted, height: 1.5),
          ),
          const SizedBox(height: KSpace.lg),
          if (_sent)
            Text(
              'Sent. Thank you.',
              style: KType.sans(size: 15, weight: FontWeight.w600, color: KC.primary),
            )
          else ...[
            KTextField(
              controller: _body,
              hint: 'What you saw, or how to reach you',
              minLines: 3,
              maxLines: 5,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: KSpace.md),
            KButton(
              label: 'Send privately',
              onPressed: _body.text.trim().isEmpty
                  ? null
                  : () async {
                      await KasatScope.of(context).alerts.sendTip(
                            alertId: widget.alert.id,
                            body: _body.text,
                          );
                      if (!mounted) return;
                      setState(() => _sent = true);
                    },
            ),
          ],
        ],
      ),
    );
  }
}
