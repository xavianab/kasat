import 'package:flutter/material.dart';

import '../../../models/approx_location.dart';
import '../../../theme/kasat_theme.dart';
import '../../../widgets/k_field.dart';
import '../../../widgets/soft_badge.dart';

/// Ethiopian sub-city and nearest landmark selector.
///
/// Replaces the latitude/longitude coordinate picker: Ethiopian users navigate
/// by Addis Ababa sub-city (Kifle Ketema) and familiar neighborhood landmarks,
/// not decimal GPS coordinates. Both fields are optional — she can submit a
/// report with neither, one, or both.
class LocationPicker extends StatelessWidget {
  const LocationPicker({
    super.key,
    required this.selectedSubCity,
    required this.onSubCityChanged,
    required this.landmarkController,
    required this.resolved,
    required this.onChanged,
  });

  static const subCityDropdownKey = Key('subcity-dropdown');
  static const landmarkFieldKey = Key('landmark-field');

  final String? selectedSubCity;
  final ValueChanged<String?> onSubCityChanged;
  final TextEditingController landmarkController;
  final ApproxLocation? resolved;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const KFieldLabel('Addis Ababa sub-city (ክፍለ ከተማ)', optional: true),
        Container(
          key: subCityDropdownKey,
          padding: const EdgeInsets.symmetric(horizontal: KSpace.md),
          decoration: BoxDecoration(
            color: KC.surfaceAlt,
            borderRadius: KRadius.rMd,
            border: Border.all(
              color: selectedSubCity != null ? KC.primary : KC.border,
              width: 1.4,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: selectedSubCity,
              isExpanded: true,
              dropdownColor: KC.surface,
              borderRadius: KRadius.rMd,
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: KC.muted,
              ),
              hint: Text(
                'Choose sub-city (optional)',
                style: KType.sans(size: 15, color: KC.faint),
              ),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text(
                    'Prefer not to say / Skip sub-city',
                    style: KType.sans(size: 14.5, color: KC.muted),
                  ),
                ),
                for (final sub in kAddisAbabaSubCities)
                  DropdownMenuItem<String?>(
                    value: sub.nameEn,
                    child: Text(
                      sub.bilingualLabel,
                      style: KType.sans(
                        size: 15,
                        weight: FontWeight.w500,
                        color: KC.text,
                      ),
                    ),
                  ),
              ],
              onChanged: (value) {
                onSubCityChanged(value);
                onChanged();
              },
            ),
          ),
        ),
        const SizedBox(height: KSpace.lg),
        const KFieldLabel('Nearest landmark (አቅራቢያ የሚገኝ ምልክት)', optional: true),
        KTextField(
          key: landmarkFieldKey,
          controller: landmarkController,
          hint: 'e.g., Near Bole Medhanialem Church, opposite Edna Mall',
          onChanged: (_) => onChanged(),
        ),
        const SizedBox(height: KSpace.md),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: KSpace.md,
            vertical: KSpace.md,
          ),
          decoration: BoxDecoration(
            color: KC.surfaceAlt,
            borderRadius: KRadius.rMd,
            border: Border.all(
              color: resolved != null ? KC.primary : KC.border,
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.place_outlined,
                size: 18,
                color: resolved != null ? KC.primary : KC.faint,
              ),
              const SizedBox(width: KSpace.sm),
              Expanded(
                child: Text(
                  resolved?.displayLabel ?? 'No location attached (optional)',
                  style: resolved != null
                      ? KType.sans(
                          size: 13.5,
                          weight: FontWeight.w600,
                          color: KC.secondary,
                        )
                      : KType.sans(size: 13.5, color: KC.faint),
                ),
              ),
              const SoftBadge(
                'Optional',
                color: KC.faint,
                dense: true,
                size: 11.5,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
