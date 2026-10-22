import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Languages the picker shows. Only [ready] locales actually swap copy.
class AppLanguage {
  const AppLanguage({
    required this.code,
    required this.englishName,
    required this.nativeName,
    required this.ready,
  });

  final String code;
  final String englishName;
  final String nativeName;
  final bool ready;
}

const kAppLanguages = <AppLanguage>[
  AppLanguage(code: 'en', englishName: 'English', nativeName: 'English', ready: true),
  AppLanguage(code: 'am', englishName: 'Amharic', nativeName: 'አማርኛ', ready: true),
  AppLanguage(code: 'om', englishName: 'Oromifa', nativeName: 'Afaan Oromoo', ready: false),
  AppLanguage(code: 'ti', englishName: 'Tigrinya', nativeName: 'ትግርኛ', ready: false),
  AppLanguage(code: 'so', englishName: 'Somali', nativeName: 'Af-Soomaali', ready: false),
  AppLanguage(code: 'aa', englishName: 'Afar', nativeName: 'Qafar af', ready: false),
];

/// JSON-backed strings. Adding Oromifa later is dropping in `om.json`.
class I18n extends ChangeNotifier {
  I18n();

  static const _prefKey = 'kasat.i18n.lang.v1';
  static const fallback = 'en';

  final Map<String, Map<String, String>> _tables = {};
  String _code = fallback;
  late SharedPreferences _prefs;

  String get code => _code;

  AppLanguage get language =>
      kAppLanguages.firstWhere((l) => l.code == _code, orElse: () => kAppLanguages.first);

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _tables['en'] = await _loadJson('en');
    _tables['am'] = await _loadJson('am');
    final stored = _prefs.getString(_prefKey);
    final match = kAppLanguages.cast<AppLanguage?>().firstWhere(
          (l) => l!.code == stored && l.ready,
          orElse: () => null,
        );
    _code = match?.code ?? fallback;
    notifyListeners();
  }

  Future<Map<String, String>> _loadJson(String code) async {
    final raw =
        await rootBundle.loadString('assets/i18n/$code.json', cache: false);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map((k, v) => MapEntry(k, '$v'));
  }

  /// Returns false when [code] is a Coming-soon language — caller should toast.
  Future<bool> trySet(String code) async {
    final lang = kAppLanguages.cast<AppLanguage?>().firstWhere(
          (l) => l!.code == code,
          orElse: () => null,
        );
    if (lang == null) return false;
    if (!lang.ready) return false;
    _code = lang.code;
    await _prefs.setString(_prefKey, _code);
    notifyListeners();
    return true;
  }

  String t(String key, [Map<String, String> vars = const {}]) {
    var value = _tables[_code]?[key] ?? _tables[fallback]?[key] ?? key;
    for (final entry in vars.entries) {
      value = value.replaceAll('{${entry.key}}', entry.value);
    }
    return value;
  }
}
