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
      padding: const EdgeInsets.fromLTRB(
        KSpace.lg,
        KSpace.sm,
        KSpace.lg,
        KSpace.xxl,
      ),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
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
          KNote(
            title: 'Prefer to speak with a GBV hotline instead of police?',
            icon: Icons.favorite_outline_rounded,
            color: KC.primary,
            body: 'EWLA 7711 is a free, confidential GBV hotline. You can speak '
                'with someone in Amharic, Afan Oromo, or Tigrigna without '
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
                'are verified for ${country?.name ?? 'your country'}. This '
                'app will not dial an unconfirmed number. If you are in danger '
                'now, use a number you know.',
          ),
          const SizedBox(height: KSpace.md),
        ],
        if (grouped.isEmpty)
          KNote(
            title: 'No lines for your country yet',
            icon: Icons.travel_explore_outlined,
            color: KC.secondary,
            body: 'Kasat has not been set up for your country. Reporting still '
                'works, but this screen cannot suggest anyone to call.',
          )
        else
          for (final entry in grouped.entries) ...[
            _KindSection(kind: entry.key, contacts: entry.value),
            const SizedBox(height: KSpace.lg),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(kind.icon, size: 18, color: kind.color),
            const SizedBox(width: KSpace.sm),
            Expanded(
              child: Text(
                kind.label,
                style: KType.sans(size: 16, weight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: KSpace.sm),
        for (final contact in contacts)
          _ContactRow(
            contact: contact,
            onTap: () => Dialer.call(context, contact),
          ),
      ],
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
        color: KC.surface,
        borderRadius: KRadius.rMd,
        child: InkWell(
          borderRadius: KRadius.rMd,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(KSpace.md),
            decoration: BoxDecoration(
              borderRadius: KRadius.rMd,
              border: Border.all(color: KC.border),
            ),
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
                            SoftBadge(
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
                    color: contact.verified ? KC.onPrimary : KC.faint,
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
