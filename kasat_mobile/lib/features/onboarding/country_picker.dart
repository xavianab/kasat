import 'package:flutter/material.dart';

import '../../models/country.dart';
import '../../theme/kasat_theme.dart';
import '../../widgets/k_field.dart';
import '../../widgets/kasat_button.dart';

/// Searchable list of every country. Active ones (Ethiopia, United States)
/// select. Everyone else gets a calm notice — never an error.
class CountryPicker extends StatefulWidget {
  const CountryPicker({
    super.key,
    required this.selectedCode,
    required this.onSelect,
  });

  final String? selectedCode;
  final ValueChanged<String> onSelect;

  @override
  State<CountryPicker> createState() => _CountryPickerState();
}

class _CountryPickerState extends State<CountryPicker> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _onTap(Country country) async {
    if (country.active) {
      widget.onSelect(country.code);
      return;
    }
    await showCountryUnavailableNotice(context, country);
  }

  @override
  Widget build(BuildContext context) {
    final matches = countriesMatching(_query.text);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KTextField(
          controller: _query,
          hint: 'Search countries',
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: KSpace.md),
        if (matches.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: KSpace.xl),
            child: Text(
              'No country matches that.',
              textAlign: TextAlign.center,
              style: KType.sans(size: 14, color: KC.muted),
            ),
          )
        else
          for (final country in matches)
            _CountryTile(
              key: ValueKey('country-${country.code}'),
              country: country,
              selected: country.code == widget.selectedCode,
              onTap: () => _onTap(country),
            ),
      ],
    );
  }
}

class _CountryTile extends StatelessWidget {
  const _CountryTile({
    super.key,
    required this.country,
    required this.selected,
    required this.onTap,
  });

  final Country country;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: KSpace.sm),
      child: Material(
        color: selected ? KC.primarySoft : KC.surface,
        borderRadius: KRadius.rMd,
        child: InkWell(
          borderRadius: KRadius.rMd,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: KSpace.lg, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(
                color: selected ? KC.primary : KC.border,
                width: selected ? 1.8 : 1.4,
              ),
              borderRadius: KRadius.rMd,
            ),
            child: Row(
              children: [
                Text(country.flag, style: const TextStyle(fontSize: 22, height: 1)),
                const SizedBox(width: KSpace.md),
                Expanded(
                  child: Text(
                    country.name,
                    style: KType.sans(size: 16, weight: FontWeight.w600),
                  ),
                ),
                if (selected)
                  const Icon(Icons.check_circle_rounded, color: KC.primary, size: 22)
                else if (!country.active)
                  Text(
                    'Soon',
                    style: KType.sans(size: 12.5, color: KC.faint),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Neutral, friendly, no red, no alarm icon.
Future<void> showCountryUnavailableNotice(BuildContext context, Country country) {
  return showDialog<void>(
    context: context,
    barrierColor: const Color(0x663D2A2A),
    builder: (context) => Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 320,
          margin: const EdgeInsets.symmetric(horizontal: KSpace.xl),
          padding: const EdgeInsets.all(KSpace.xl),
          decoration: BoxDecoration(
            color: KC.surface,
            borderRadius: KRadius.rLg,
            border: Border.all(color: KC.border),
            boxShadow: KShadow.lift,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(country.flag, style: const TextStyle(fontSize: 36)),
              const SizedBox(height: KSpace.md),
              Text(
                'Kasat isn\u2019t in your country yet. We\u2019re working on it.',
                textAlign: TextAlign.center,
                style: KType.serif(size: 20, height: 1.3),
              ),
              const SizedBox(height: KSpace.sm),
              Text(
                'We\u2019ll open ${country.name} as soon as the support lines '
                'are in place. You can keep browsing the list in the meantime.',
                textAlign: TextAlign.center,
                style: KType.sans(size: 14, color: KC.muted, height: 1.5),
              ),
              const SizedBox(height: KSpace.xl),
              KButton(
                label: 'OK',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
