import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/dialer.dart';
import '../../models/country.dart';
import '../../theme/kasat_theme.dart';
import '../../widgets/panel.dart';
import '../../widgets/soft_badge.dart';
import 'emergency_contacts.dart';

/// Help lines for the survivor's own country.
///
/// Everything here comes from [emergencyContactsByCountry] keyed on the country
/// chosen in Settings (defaulting to Ethiopia 'ET' with zero setup).
class ResourcesView extends StatelessWidget {
  const ResourcesView({super.key});

  @override
  Widget build(BuildContext context) {
    final code = KasatScope.of(context).settings.effectiveCountryCode;
    final country = countryByCode(code);
    final grouped = groupedContactsForCountry(code);
    final unverified = contactsForCountry(code).where((c) => !c.verified).length;

    return ListView(
      padding:
          const EdgeInsets.fromLTRB(KSpace.lg, KSpace.xs, KSpace.lg, KSpace.xxl),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Hotlines & support connects to EWLA 7711 and other support lines in ${country?.name ?? 'your country'}, not police.',
                style: KType.sans(size: 14, color: KC.muted, height: 1.5),
              ),
            ),
            if (country != null) ...[
              const SizedBox(width: KSpace.sm),
              SoftBadge(country.code, color: KC.secondary, dense: true),
            ],
          ],
        ),
        const SizedBox(height: KSpace.lg),
        if (code == 'ET') ...[
          const KNote(
            title: 'Prefer to speak with a GBV hotline instead of police?',
            icon: Icons.favorite_outline_rounded,
            color: KC.primary,
            body: 'For many women, a confidential gender-based violence hotline '
                'is safer and more appropriate than calling police. EWLA’s '
                '7711 toll-free GBV hotline offers confidential support and '
                'legal guidance in Amharic, Afan Oromo, and Tigrigna without '
                'opening a police report.',
          ),
          const SizedBox(height: KSpace.md),
        ],
        if (unverified > 0) ...[
          KNote(
            title: 'These numbers are not confirmed yet',
            icon: Icons.info_outline_rounded,
            color: KC.secondary,
            body: '$unverified of the lines below are placeholders while they '
                'are being verified for ${country?.name ?? 'your country'}. This '
                'app will not dial an unconfirmed number. If you are in danger '
                'now, use a number you know.',
          ),
          const SizedBox(height: KSpace.md),
        ],
        if (grouped.isEmpty)
          const KNote(
            title: 'No lines for your country yet',
            icon: Icons.travel_explore_outlined,
            color: KC.secondary,
            body: 'Kasat has not been set up for your country. Reporting still '
                'works, but this screen cannot suggest anyone to call.',
          )
        else
          for (final entry in grouped.entries) ...[
            _KindSection(kind: entry.key, contacts: entry.value),
            const SizedBox(height: KSpace.md),
          ],
      ],
    );
  }
}

class _KindSection extends StatelessWidget {
  const _KindSection({required this.kind, required this.contacts});

  final ContactKind kind;
  final List<EmergencyContact> contacts;

  @override
  Widget build(BuildContext context) {
    return KPanel(
      title: kind.label,
      padding:
          const EdgeInsets.symmetric(horizontal: KSpace.md, vertical: KSpace.md),
      trailing: Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: kind.color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(kind.icon, size: 16, color: kind.color),
      ),
      child: Column(
        children: [
          for (final contact in contacts)
            _ContactRow(
              contact: contact,
              onTap: () => Dialer.call(context, contact),
            ),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.contact, required this.onTap});

  final EmergencyContact contact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: KSpace.sm),
      child: Material(
        color: KC.surfaceAlt,
        borderRadius: KRadius.rMd,
        child: InkWell(
          borderRadius: KRadius.rMd,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(KSpace.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        contact.name,
                        style: KType.sans(
                          size: 14.5,
                          weight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        contact.blurb,
                        style: KType.sans(
                          size: 12.5,
                          color: KC.muted,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: KSpace.sm),
                      Wrap(
                        spacing: KSpace.sm,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            contact.number,
                            style: KType.code(size: 13, color: KC.secondary),
                          ),
                          if (!contact.verified)
                            const SoftBadge(
                              'Not confirmed yet',
                              color: KC.faint,
                              dense: true,
                              size: 11.5,
                            ),
                          Text(
                            contact.hours,
                            style: KType.sans(size: 11.5, color: KC.faint),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: KSpace.md),
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: contact.verified ? KC.primary : KC.border,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    contact.verified
                        ? Icons.call_rounded
                        : Icons.info_outline_rounded,
                    size: 19,
                    color: contact.verified ? Colors.white : KC.faint,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
