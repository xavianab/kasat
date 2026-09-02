import 'package:flutter/material.dart';

import '../../app.dart';
import '../../models/country.dart';
import '../../theme/kasat_theme.dart';
import '../../widgets/panel.dart';
import '../../widgets/soft_backdrop.dart';
import '../onboarding/country_picker.dart';

/// Country can be changed after setup without wiping the PIN. Only an active
/// country is stored.
class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  @override
  Widget build(BuildContext context) {
    final settings = KasatScope.of(context).settings;
    final current = countryByCode(settings.countryCode);

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
                    Text('Settings', style: KType.serif(size: 22)),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(KSpace.xl),
                  children: [
                    KPanel(
                      title: 'Your country',
                      subtitle: current == null
                          ? 'Used for help lines and where a report is sent.'
                          : '${current.flag}  ${current.name}',
                      child: CountryPicker(
                        selectedCode: settings.countryCode,
                        onSelect: (code) async {
                          await settings.setCountryCode(code);
                          if (mounted) setState(() {});
                        },
                      ),
                    ),
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
