/// A jurisdiction Kasat can list.
///
/// [active] is the only switch that matters for launch. Everyone
/// else appears in the picker and sees a calm 'not yet' notice.
class Country {
  const Country({
    required this.code,
    required this.name,
    required this.dialPrefix,
    required this.active,
  });

  /// ISO 3166-1 alpha-2. Stored locally and sent with a report.
  final String code;
  final String name;
  final String dialPrefix;
  final bool active;

  /// Regional-indicator flag for [code], e.g. ET → 🇪🇹.
  String get flag {
    final a = code.codeUnitAt(0);
    final b = code.codeUnitAt(1);
    return String.fromCharCodes([
      0x1F1E6 + (a - 0x41),
      0x1F1E6 + (b - 0x41),
    ]);
  }
}

const kCountries = <Country>[
  Country(code: 'AF', name: 'Afghanistan', dialPrefix: '+93', active: false),
  Country(code: 'AL', name: 'Albania', dialPrefix: '+355', active: false),
  Country(code: 'DZ', name: 'Algeria', dialPrefix: '+213', active: false),
  Country(code: 'AD', name: 'Andorra', dialPrefix: '+376', active: false),
  Country(code: 'AO', name: 'Angola', dialPrefix: '+244', active: false),
  Country(code: 'AG', name: 'Antigua and Barbuda', dialPrefix: '+1', active: false),
  Country(code: 'AR', name: 'Argentina', dialPrefix: '+54', active: false),
  Country(code: 'AM', name: 'Armenia', dialPrefix: '+374', active: false),
  Country(code: 'AU', name: 'Australia', dialPrefix: '+61', active: false),
  Country(code: 'AT', name: 'Austria', dialPrefix: '+43', active: false),
  Country(code: 'AZ', name: 'Azerbaijan', dialPrefix: '+994', active: false),
  Country(code: 'BS', name: 'Bahamas', dialPrefix: '+1', active: false),
  Country(code: 'BH', name: 'Bahrain', dialPrefix: '+973', active: false),
  Country(code: 'BD', name: 'Bangladesh', dialPrefix: '+880', active: false),
  Country(code: 'BB', name: 'Barbados', dialPrefix: '+1', active: false),
  Country(code: 'BY', name: 'Belarus', dialPrefix: '+375', active: false),
  Country(code: 'BE', name: 'Belgium', dialPrefix: '+32', active: false),
  Country(code: 'BZ', name: 'Belize', dialPrefix: '+501', active: false),
  Country(code: 'BJ', name: 'Benin', dialPrefix: '+229', active: false),
  Country(code: 'BT', name: 'Bhutan', dialPrefix: '+975', active: false),
  Country(code: 'BO', name: 'Bolivia', dialPrefix: '+591', active: false),
  Country(code: 'BA', name: 'Bosnia and Herzegovina', dialPrefix: '+387', active: false),
  Country(code: 'BW', name: 'Botswana', dialPrefix: '+267', active: false),
  Country(code: 'BR', name: 'Brazil', dialPrefix: '+55', active: false),
  Country(code: 'BN', name: 'Brunei', dialPrefix: '+673', active: false),
  Country(code: 'BG', name: 'Bulgaria', dialPrefix: '+359', active: false),
  Country(code: 'BF', name: 'Burkina Faso', dialPrefix: '+226', active: false),
  Country(code: 'BI', name: 'Burundi', dialPrefix: '+257', active: false),
  Country(code: 'CV', name: 'Cabo Verde', dialPrefix: '+238', active: false),
  Country(code: 'KH', name: 'Cambodia', dialPrefix: '+855', active: false),
  Country(code: 'CM', name: 'Cameroon', dialPrefix: '+237', active: false),
  Country(code: 'CA', name: 'Canada', dialPrefix: '+1', active: false),
  Country(code: 'CF', name: 'Central African Republic', dialPrefix: '+236', active: false),
  Country(code: 'TD', name: 'Chad', dialPrefix: '+235', active: false),
  Country(code: 'CL', name: 'Chile', dialPrefix: '+56', active: false),
  Country(code: 'CN', name: 'China', dialPrefix: '+86', active: false),
  Country(code: 'CO', name: 'Colombia', dialPrefix: '+57', active: false),
  Country(code: 'KM', name: 'Comoros', dialPrefix: '+269', active: false),
  Country(code: 'CG', name: 'Congo', dialPrefix: '+242', active: false),
  Country(code: 'CD', name: 'Congo (DRC)', dialPrefix: '+243', active: false),
  Country(code: 'CR', name: 'Costa Rica', dialPrefix: '+506', active: false),
  Country(code: 'HR', name: 'Croatia', dialPrefix: '+385', active: false),
  Country(code: 'CU', name: 'Cuba', dialPrefix: '+53', active: false),
  Country(code: 'CY', name: 'Cyprus', dialPrefix: '+357', active: false),
  Country(code: 'CZ', name: 'Czechia', dialPrefix: '+420', active: false),
  Country(code: 'CI', name: 'Côte d’Ivoire', dialPrefix: '+225', active: false),
  Country(code: 'DK', name: 'Denmark', dialPrefix: '+45', active: false),
  Country(code: 'DJ', name: 'Djibouti', dialPrefix: '+253', active: false),
  Country(code: 'DM', name: 'Dominica', dialPrefix: '+1', active: false),
  Country(code: 'DO', name: 'Dominican Republic', dialPrefix: '+1', active: false),
  Country(code: 'EC', name: 'Ecuador', dialPrefix: '+593', active: false),
  Country(code: 'EG', name: 'Egypt', dialPrefix: '+20', active: false),
  Country(code: 'SV', name: 'El Salvador', dialPrefix: '+503', active: false),
  Country(code: 'GQ', name: 'Equatorial Guinea', dialPrefix: '+240', active: false),
  Country(code: 'ER', name: 'Eritrea', dialPrefix: '+291', active: false),
  Country(code: 'EE', name: 'Estonia', dialPrefix: '+372', active: false),
  Country(code: 'SZ', name: 'Eswatini', dialPrefix: '+268', active: false),
  Country(code: 'ET', name: 'Ethiopia', dialPrefix: '+251', active: true),
  Country(code: 'FJ', name: 'Fiji', dialPrefix: '+679', active: false),
  Country(code: 'FI', name: 'Finland', dialPrefix: '+358', active: false),
  Country(code: 'FR', name: 'France', dialPrefix: '+33', active: false),
  Country(code: 'GA', name: 'Gabon', dialPrefix: '+241', active: false),
  Country(code: 'GM', name: 'Gambia', dialPrefix: '+220', active: false),
  Country(code: 'GE', name: 'Georgia', dialPrefix: '+995', active: false),
  Country(code: 'DE', name: 'Germany', dialPrefix: '+49', active: false),
  Country(code: 'GH', name: 'Ghana', dialPrefix: '+233', active: false),
  Country(code: 'GR', name: 'Greece', dialPrefix: '+30', active: false),
  Country(code: 'GD', name: 'Grenada', dialPrefix: '+1', active: false),
  Country(code: 'GT', name: 'Guatemala', dialPrefix: '+502', active: false),
  Country(code: 'GN', name: 'Guinea', dialPrefix: '+224', active: false),
  Country(code: 'GW', name: 'Guinea-Bissau', dialPrefix: '+245', active: false),
  Country(code: 'GY', name: 'Guyana', dialPrefix: '+592', active: false),
  Country(code: 'HT', name: 'Haiti', dialPrefix: '+509', active: false),
  Country(code: 'HN', name: 'Honduras', dialPrefix: '+504', active: false),
  Country(code: 'HU', name: 'Hungary', dialPrefix: '+36', active: false),
  Country(code: 'IS', name: 'Iceland', dialPrefix: '+354', active: false),
  Country(code: 'IN', name: 'India', dialPrefix: '+91', active: false),
  Country(code: 'ID', name: 'Indonesia', dialPrefix: '+62', active: false),
  Country(code: 'IR', name: 'Iran', dialPrefix: '+98', active: false),
  Country(code: 'IQ', name: 'Iraq', dialPrefix: '+964', active: false),
  Country(code: 'IE', name: 'Ireland', dialPrefix: '+353', active: false),
  Country(code: 'IL', name: 'Israel', dialPrefix: '+972', active: false),
  Country(code: 'IT', name: 'Italy', dialPrefix: '+39', active: false),
  Country(code: 'JM', name: 'Jamaica', dialPrefix: '+1', active: false),
  Country(code: 'JP', name: 'Japan', dialPrefix: '+81', active: false),
  Country(code: 'JO', name: 'Jordan', dialPrefix: '+962', active: false),
  Country(code: 'KZ', name: 'Kazakhstan', dialPrefix: '+7', active: false),
  Country(code: 'KE', name: 'Kenya', dialPrefix: '+254', active: false),
  Country(code: 'KI', name: 'Kiribati', dialPrefix: '+686', active: false),
  Country(code: 'KW', name: 'Kuwait', dialPrefix: '+965', active: false),
  Country(code: 'KG', name: 'Kyrgyzstan', dialPrefix: '+996', active: false),
  Country(code: 'LA', name: 'Laos', dialPrefix: '+856', active: false),
  Country(code: 'LV', name: 'Latvia', dialPrefix: '+371', active: false),
  Country(code: 'LB', name: 'Lebanon', dialPrefix: '+961', active: false),
  Country(code: 'LS', name: 'Lesotho', dialPrefix: '+266', active: false),
  Country(code: 'LR', name: 'Liberia', dialPrefix: '+231', active: false),
  Country(code: 'LY', name: 'Libya', dialPrefix: '+218', active: false),
  Country(code: 'LI', name: 'Liechtenstein', dialPrefix: '+423', active: false),
  Country(code: 'LT', name: 'Lithuania', dialPrefix: '+370', active: false),
  Country(code: 'LU', name: 'Luxembourg', dialPrefix: '+352', active: false),
  Country(code: 'MG', name: 'Madagascar', dialPrefix: '+261', active: false),
  Country(code: 'MW', name: 'Malawi', dialPrefix: '+265', active: false),
  Country(code: 'MY', name: 'Malaysia', dialPrefix: '+60', active: false),
  Country(code: 'MV', name: 'Maldives', dialPrefix: '+960', active: false),
  Country(code: 'ML', name: 'Mali', dialPrefix: '+223', active: false),
  Country(code: 'MT', name: 'Malta', dialPrefix: '+356', active: false),
  Country(code: 'MH', name: 'Marshall Islands', dialPrefix: '+692', active: false),
  Country(code: 'MR', name: 'Mauritania', dialPrefix: '+222', active: false),
  Country(code: 'MU', name: 'Mauritius', dialPrefix: '+230', active: false),
  Country(code: 'MX', name: 'Mexico', dialPrefix: '+52', active: false),
  Country(code: 'FM', name: 'Micronesia', dialPrefix: '+691', active: false),
  Country(code: 'MD', name: 'Moldova', dialPrefix: '+373', active: false),
  Country(code: 'MC', name: 'Monaco', dialPrefix: '+377', active: false),
  Country(code: 'MN', name: 'Mongolia', dialPrefix: '+976', active: false),
  Country(code: 'ME', name: 'Montenegro', dialPrefix: '+382', active: false),
  Country(code: 'MA', name: 'Morocco', dialPrefix: '+212', active: false),
  Country(code: 'MZ', name: 'Mozambique', dialPrefix: '+258', active: false),
  Country(code: 'MM', name: 'Myanmar', dialPrefix: '+95', active: false),
  Country(code: 'NA', name: 'Namibia', dialPrefix: '+264', active: false),
  Country(code: 'NR', name: 'Nauru', dialPrefix: '+674', active: false),
  Country(code: 'NP', name: 'Nepal', dialPrefix: '+977', active: false),
  Country(code: 'NL', name: 'Netherlands', dialPrefix: '+31', active: false),
  Country(code: 'NZ', name: 'New Zealand', dialPrefix: '+64', active: false),
  Country(code: 'NI', name: 'Nicaragua', dialPrefix: '+505', active: false),
  Country(code: 'NE', name: 'Niger', dialPrefix: '+227', active: false),
  Country(code: 'NG', name: 'Nigeria', dialPrefix: '+234', active: false),
  Country(code: 'KP', name: 'North Korea', dialPrefix: '+850', active: false),
  Country(code: 'MK', name: 'North Macedonia', dialPrefix: '+389', active: false),
  Country(code: 'NO', name: 'Norway', dialPrefix: '+47', active: false),
  Country(code: 'OM', name: 'Oman', dialPrefix: '+968', active: false),
  Country(code: 'PK', name: 'Pakistan', dialPrefix: '+92', active: false),
  Country(code: 'PW', name: 'Palau', dialPrefix: '+680', active: false),
  Country(code: 'PS', name: 'Palestine', dialPrefix: '+970', active: false),
  Country(code: 'PA', name: 'Panama', dialPrefix: '+507', active: false),
  Country(code: 'PG', name: 'Papua New Guinea', dialPrefix: '+675', active: false),
  Country(code: 'PY', name: 'Paraguay', dialPrefix: '+595', active: false),
  Country(code: 'PE', name: 'Peru', dialPrefix: '+51', active: false),
  Country(code: 'PH', name: 'Philippines', dialPrefix: '+63', active: false),
  Country(code: 'PL', name: 'Poland', dialPrefix: '+48', active: false),
  Country(code: 'PT', name: 'Portugal', dialPrefix: '+351', active: false),
  Country(code: 'QA', name: 'Qatar', dialPrefix: '+974', active: false),
  Country(code: 'RO', name: 'Romania', dialPrefix: '+40', active: false),
  Country(code: 'RU', name: 'Russia', dialPrefix: '+7', active: false),
  Country(code: 'RW', name: 'Rwanda', dialPrefix: '+250', active: false),
  Country(code: 'KN', name: 'Saint Kitts and Nevis', dialPrefix: '+1', active: false),
  Country(code: 'LC', name: 'Saint Lucia', dialPrefix: '+1', active: false),
  Country(code: 'VC', name: 'Saint Vincent and the Grenadines', dialPrefix: '+1', active: false),
  Country(code: 'WS', name: 'Samoa', dialPrefix: '+685', active: false),
  Country(code: 'SM', name: 'San Marino', dialPrefix: '+378', active: false),
  Country(code: 'SA', name: 'Saudi Arabia', dialPrefix: '+966', active: false),
  Country(code: 'SN', name: 'Senegal', dialPrefix: '+221', active: false),
  Country(code: 'RS', name: 'Serbia', dialPrefix: '+381', active: false),
  Country(code: 'SC', name: 'Seychelles', dialPrefix: '+248', active: false),
  Country(code: 'SL', name: 'Sierra Leone', dialPrefix: '+232', active: false),
  Country(code: 'SG', name: 'Singapore', dialPrefix: '+65', active: false),
  Country(code: 'SK', name: 'Slovakia', dialPrefix: '+421', active: false),
  Country(code: 'SI', name: 'Slovenia', dialPrefix: '+386', active: false),
  Country(code: 'SB', name: 'Solomon Islands', dialPrefix: '+677', active: false),
  Country(code: 'SO', name: 'Somalia', dialPrefix: '+252', active: false),
  Country(code: 'ZA', name: 'South Africa', dialPrefix: '+27', active: false),
  Country(code: 'KR', name: 'South Korea', dialPrefix: '+82', active: false),
  Country(code: 'SS', name: 'South Sudan', dialPrefix: '+211', active: false),
  Country(code: 'ES', name: 'Spain', dialPrefix: '+34', active: false),
  Country(code: 'LK', name: 'Sri Lanka', dialPrefix: '+94', active: false),
  Country(code: 'SD', name: 'Sudan', dialPrefix: '+249', active: false),
  Country(code: 'SR', name: 'Suriname', dialPrefix: '+597', active: false),
  Country(code: 'SE', name: 'Sweden', dialPrefix: '+46', active: false),
  Country(code: 'CH', name: 'Switzerland', dialPrefix: '+41', active: false),
  Country(code: 'SY', name: 'Syria', dialPrefix: '+963', active: false),
  Country(code: 'ST', name: 'São Tomé and Príncipe', dialPrefix: '+239', active: false),
  Country(code: 'TW', name: 'Taiwan', dialPrefix: '+886', active: false),
  Country(code: 'TJ', name: 'Tajikistan', dialPrefix: '+992', active: false),
  Country(code: 'TZ', name: 'Tanzania', dialPrefix: '+255', active: false),
  Country(code: 'TH', name: 'Thailand', dialPrefix: '+66', active: false),
  Country(code: 'TL', name: 'Timor-Leste', dialPrefix: '+670', active: false),
  Country(code: 'TG', name: 'Togo', dialPrefix: '+228', active: false),
  Country(code: 'TO', name: 'Tonga', dialPrefix: '+676', active: false),
  Country(code: 'TT', name: 'Trinidad and Tobago', dialPrefix: '+1', active: false),
  Country(code: 'TN', name: 'Tunisia', dialPrefix: '+216', active: false),
  Country(code: 'TM', name: 'Turkmenistan', dialPrefix: '+993', active: false),
  Country(code: 'TV', name: 'Tuvalu', dialPrefix: '+688', active: false),
  Country(code: 'TR', name: 'Türkiye', dialPrefix: '+90', active: false),
  Country(code: 'UG', name: 'Uganda', dialPrefix: '+256', active: false),
  Country(code: 'UA', name: 'Ukraine', dialPrefix: '+380', active: false),
  Country(code: 'AE', name: 'United Arab Emirates', dialPrefix: '+971', active: false),
  Country(code: 'GB', name: 'United Kingdom', dialPrefix: '+44', active: false),
  Country(code: 'US', name: 'United States', dialPrefix: '+1', active: true),
  Country(code: 'UY', name: 'Uruguay', dialPrefix: '+598', active: false),
  Country(code: 'UZ', name: 'Uzbekistan', dialPrefix: '+998', active: false),
  Country(code: 'VU', name: 'Vanuatu', dialPrefix: '+678', active: false),
  Country(code: 'VA', name: 'Vatican City', dialPrefix: '+39', active: false),
  Country(code: 'VE', name: 'Venezuela', dialPrefix: '+58', active: false),
  Country(code: 'VN', name: 'Vietnam', dialPrefix: '+84', active: false),
  Country(code: 'YE', name: 'Yemen', dialPrefix: '+967', active: false),
  Country(code: 'ZM', name: 'Zambia', dialPrefix: '+260', active: false),
  Country(code: 'ZW', name: 'Zimbabwe', dialPrefix: '+263', active: false),
];

Country? countryByCode(String? code) {
  if (code == null) return null;
  for (final country in kCountries) {
    if (country.code == code) return country;
  }
  return null;
}

Iterable<Country> get activeCountries => kCountries.where((c) => c.active);

List<Country> countriesMatching(String query) {
  final q = query.trim().toLowerCase();
  final source = q.isEmpty
      ? List<Country>.from(kCountries)
      : kCountries
          .where((c) => c.name.toLowerCase().contains(q) || c.code.toLowerCase() == q)
          .toList();
  // Live countries first so Ethiopia and the United States are not buried.
  source.sort((a, b) {
    if (a.active != b.active) return a.active ? -1 : 1;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
  return source;
}
