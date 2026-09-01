/// A jurisdiction Kasat can operate in.
///
/// Only Ethiopia is [active] today. The others are listed so the picker, the
/// contact table, and the report payload are all exercised against a
/// multi-country shape from day one — turning one on should be a data change,
/// never a code change.
class Country {
  const Country({
    required this.code,
    required this.name,
    required this.dialPrefix,
    required this.active,
  });

  /// ISO 3166-1 alpha-2. This is what gets stored and what rides along on a
  /// submitted report.
  final String code;

  final String name;

  /// E.164 prefix, used when rendering a national number for dialling.
  final String dialPrefix;

  /// False means "listed but not yet launched": no verified contacts, no
  /// routing on the operator side.
  final bool active;
}

const kCountries = <Country>[
  Country(code: 'ET', name: 'Ethiopia', dialPrefix: '+251', active: true),
  Country(code: 'KE', name: 'Kenya', dialPrefix: '+254', active: false),
  Country(code: 'SO', name: 'Somalia', dialPrefix: '+252', active: false),
  Country(code: 'DJ', name: 'Djibouti', dialPrefix: '+253', active: false),
  Country(code: 'SS', name: 'South Sudan', dialPrefix: '+211', active: false),
];

Country? countryByCode(String? code) {
  if (code == null) return null;
  for (final country in kCountries) {
    if (country.code == code) return country;
  }
  return null;
}

Iterable<Country> get activeCountries => kCountries.where((c) => c.active);
