import 'package:flutter/material.dart';

import '../../../models/approx_location.dart';
import '../../../theme/kasat_theme.dart';
import '../../../widgets/k_field.dart';

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
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final menuItemHeight = 48.0 * (textScale < 1 ? 1 : textScale);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const KFieldLabel('Addis Ababa sub-city (ክፍለ ከተማ)'),
        Container(
          key: subCityDropdownKey,
          padding: const EdgeInsets.symmetric(horizontal: KSpace.md),
          decoration: BoxDecoration(
            color: KC.surfaceAlt,
            borderRadius: KRadius.rMd,
            border: Border.all(
              color: selectedSubCity != null ? KC.primary : KC.border,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: selectedSubCity,
              isExpanded: true,
              itemHeight: menuItemHeight,
              dropdownColor: KC.surface,
              borderRadius: KRadius.rMd,
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: KC.muted,
              ),
              hint: Text(
                'Choose sub-city',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: KType.sans(size: 15, color: KC.faint),
              ),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text(
                    'Skip',
                    style: KType.sans(size: 14.5, color: KC.muted),
                  ),
                ),
                for (final sub in kAddisAbabaSubCities)
                  DropdownMenuItem<String?>(
                    value: sub.nameEn,
                    child: Text(
                      sub.bilingualLabel,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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
        const KFieldLabel('Nearest landmark (አቅራቢያ የሚገኝ ምልክት)'),
        KTextField(
          key: landmarkFieldKey,
          controller: landmarkController,
          hint: 'Near a church, school or shop',
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
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.place_outlined,
                size: 18,
                color: resolved != null ? KC.primary : KC.faint,
              ),
              const SizedBox(width: KSpace.sm),
              Expanded(
                child: Text(
                  resolved?.displayLabel ?? 'No location attached',
                  softWrap: true,
                  style: resolved != null
                      ? KType.sans(
                          size: 13.5,
                          weight: FontWeight.w600,
                          color: KC.secondary,
                        )
                      : KType.sans(size: 13.5, color: KC.faint),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
