import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../features/resources/emergency_contacts.dart';
import '../theme/kasat_theme.dart';
import '../widgets/kasat_button.dart';

/// One-tap dialling, shared by the resources screen and the crisis banner.
abstract final class Dialer {
  static Future<void> call(BuildContext context, EmergencyContact contact) async {
    // An unverified entry is a placeholder. Dialling it would either fail or,
    // worse, connect to a stranger — so the app refuses and says why.
    if (!contact.verified) {
      await _showUnverified(context, contact);
      return;
    }

    HapticFeedback.mediumImpact();
    var launched = false;
    try {
      launched = await launchUrl(Uri(scheme: 'tel', path: contact.dialable));
    } catch (_) {
      launched = false;
    }

    // The iOS Simulator has no dialler, and some locked-down handsets block the
    // tel: scheme. Falling back to a copyable number keeps the screen useful
    // instead of failing silently.
    if (!launched && context.mounted) {
      await _showManual(context, contact);
    }
  }

  static Future<void> _showUnverified(BuildContext context, EmergencyContact contact) {
    return _sheet(
      context,
      title: 'Number not confirmed yet',
      body: 'The number for ${contact.name} has not been verified for your '
          'country, so this app will not dial it. Please use a number you '
          'know, or ask someone you trust.',
      color: KC.secondary,
      icon: Icons.info_outline_rounded,
    );
  }

  static Future<void> _showManual(BuildContext context, EmergencyContact contact) {
    return _sheet(
      context,
      title: 'Cannot dial from here',
      body: 'This device cannot place calls. The number is '
          '${contact.number}, and it has been copied for you.',
      color: KC.secondary,
      icon: Icons.phone_disabled_outlined,
      onOpen: () => Clipboard.setData(ClipboardData(text: contact.number)),
    );
  }

  static Future<void> _sheet(
    BuildContext context, {
    required String title,
    required String body,
    required Color color,
    required IconData icon,
    VoidCallback? onOpen,
  }) {
    onOpen?.call();
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: KC.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(KRadius.xl)),
      ),
      builder: (context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(KSpace.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 22, color: color),
                  const SizedBox(width: KSpace.sm),
                  Expanded(child: Text(title, style: KType.serif(size: 19))),
                ],
              ),
              const SizedBox(height: KSpace.md),
              Text(body, style: KType.sans(size: 14, color: KC.muted, height: 1.6)),
              const SizedBox(height: KSpace.xl),
              KButton(
                label: 'Close',
                kind: KButtonKind.soft,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
