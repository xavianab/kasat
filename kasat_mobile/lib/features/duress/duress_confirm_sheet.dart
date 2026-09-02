import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/kasat_config.dart';
import 'duress_sms.dart';
import 'duress_store.dart';

/// Looks like a bland system sheet, not an emergency screen.
///
/// The Notes decoy list was removed from Kasat on purpose. This uses a backup
/// / storage metaphor instead so a glance does not reveal the product.
class DuressConfirmSheet extends StatefulWidget {
  const DuressConfirmSheet({super.key, required this.contact});

  final TrustedContact contact;

  static Future<void> show(BuildContext context, TrustedContact contact) {
    return showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: const Color(0xFFF2F2F7),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (_) => DuressConfirmSheet(contact: contact),
    );
  }

  @override
  State<DuressConfirmSheet> createState() => _DuressConfirmSheetState();
}

class _DuressConfirmSheetState extends State<DuressConfirmSheet> {
  late int _left = KasatConfig.duressCountdown.inSeconds;
  Timer? _timer;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_left <= 1) {
        t.cancel();
        _send();
        return;
      }
      setState(() => _left--);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _cancel() {
    _timer?.cancel();
    Navigator.of(context).pop();
  }

  Future<void> _send() async {
    if (_sending) return;
    setState(() => _sending = true);
    await offerDuressSms(widget.contact);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFC7C7CC),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 18),
            const Icon(Icons.cloud_outlined, size: 36, color: Color(0xFF8E8E93)),
            const SizedBox(height: 12),
            const Text(
              'Preparing backup…',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1C1C1E),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Keep the phone still.  $_left',
              style: const TextStyle(fontSize: 14, color: Color(0xFF8E8E93)),
            ),
            const SizedBox(height: 18),
            LinearProgressIndicator(
              value: 1 - (_left / KasatConfig.duressCountdown.inSeconds),
              color: const Color(0xFF8E8E93),
              backgroundColor: const Color(0xFFE5E5EA),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _sending ? null : () {
                  HapticFeedback.lightImpact();
                  _cancel();
                },
                child: const Text(
                  'Not now',
                  style: TextStyle(fontSize: 17, color: Color(0xFF007AFF)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
