import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/kasat_theme.dart';
import '../../widgets/kasat_button.dart';
import '../../widgets/mono_badge.dart';
import '../../widgets/panel.dart';
import 'emergency_contacts.dart';

class ResourcesView extends StatelessWidget {
  const ResourcesView({super.key});

  Future<void> _dial(BuildContext context, EmergencyContact contact) async {
    HapticFeedback.mediumImpact();
    final uri = Uri(scheme: 'tel', path: contact.dialable);

    var launched = false;
    try {
      launched = await launchUrl(uri);
    } catch (_) {
      launched = false;
    }

    // The iOS Simulator has no dialer, and some locked-down handsets block the
    // tel: scheme. Falling back to a copyable number keeps the screen useful
    // instead of failing silently.
    if (!launched && context.mounted) {
      await _showManualDial(context, contact);
    }
  }

  Future<void> _showManualDial(BuildContext context, EmergencyContact contact) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.82),
      builder: (context) => Center(
        child: Container(
          width: 290,
          padding: const EdgeInsets.all(KSpace.lg),
          decoration: BoxDecoration(
            color: KC.surface,
            border: Border.all(color: KC.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('DIALER UNAVAILABLE', style: KType.label(color: KC.warn)),
              const SizedBox(height: KSpace.md),
              Text(
                contact.name,
                textAlign: TextAlign.center,
                style: KType.sans(size: 13, weight: FontWeight.w700),
              ),
              const SizedBox(height: KSpace.sm),
              SelectableText(
                contact.number,
                style: KType.mono(size: 20, weight: FontWeight.w800, color: KC.accent),
              ),
              const SizedBox(height: KSpace.lg),
              Row(
                children: [
                  Expanded(
                    child: KButton(
                      label: 'Copy',
                      kind: KButtonKind.outline,
                      compact: true,
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: contact.number));
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                  const SizedBox(width: KSpace.sm),
                  Expanded(
                    child: KButton(
                      label: 'Close',
                      kind: KButtonKind.ghost,
                      compact: true,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final grouped = <ContactKind, List<EmergencyContact>>{};
    for (final contact in emergencyContacts) {
      grouped.putIfAbsent(contact.kind, () => []).add(contact);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(KSpace.md, KSpace.md, KSpace.md, KSpace.xl),
      children: [
        Text(
          'Support directory',
          style: KType.sans(size: 19, weight: FontWeight.w800, tracking: -0.4),
        ),
        const SizedBox(height: 3),
        Text(
          'One tap dials. Kasat does not observe, log, or route these calls.',
          style: KType.sans(size: 11.5, color: KC.muted, height: 1.35),
        ),
        const SizedBox(height: KSpace.md),
        for (final entry in grouped.entries) ...[
          KPanel(
            title: entry.key.label,
            trailing: MonoBadge(
              '${entry.value.length}',
              size: 9,
              dense: true,
              color: entry.key.color,
            ),
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < entry.value.length; i++) ...[
                  if (i > 0) const Divider(height: 1, color: KC.border),
                  _ContactRow(
                    contact: entry.value[i],
                    onDial: () => _dial(context, entry.value[i]),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: KSpace.md),
        ],
        Container(
          padding: const EdgeInsets.all(KSpace.md),
          decoration: BoxDecoration(
            border: Border.all(color: KC.border),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            'Numbers shown are placeholders for the MVP. A jurisdiction-specific '
            'directory must be loaded before deployment.',
            style: KType.sans(size: 11, color: KC.faint, height: 1.45),
          ),
        ),
      ],
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.contact, required this.onDial});

  final EmergencyContact contact;
  final VoidCallback onDial;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onDial,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: KSpace.md, vertical: KSpace.md),
        child: Row(
          children: [
            Icon(contact.kind.icon, size: 17, color: contact.kind.color),
            const SizedBox(width: KSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contact.name,
                    style: KType.sans(size: 13, weight: FontWeight.w700, height: 1.2),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        contact.number,
                        style: KType.mono(
                          size: 11,
                          weight: FontWeight.w700,
                          color: contact.kind.color,
                        ),
                      ),
                      const SizedBox(width: 6),
                      MonoBadge(contact.region, size: 8.5, dense: true, color: KC.faint),
                      const SizedBox(width: 4),
                      MonoBadge(contact.hours, size: 8.5, dense: true, color: KC.faint),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    contact.blurb,
                    style: KType.sans(size: 11, color: KC.muted, height: 1.35),
                  ),
                ],
              ),
            ),
            const SizedBox(width: KSpace.sm),
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: contact.kind.color.withValues(alpha: 0.12),
                border: Border.all(color: contact.kind.color.withValues(alpha: 0.45)),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Icon(Icons.call_rounded, size: 15, color: contact.kind.color),
            ),
          ],
        ),
      ),
    );
  }
}
