import 'package:flutter_test/flutter_test.dart';
import 'package:kasat_mobile/i18n/i18n.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('coming-soon languages refuse to switch; Amharic does', () async {
    SharedPreferences.setMockInitialValues({});
    final i18n = I18n();
    await i18n.init();
    expect(i18n.code, 'en');
    expect(await i18n.trySet('aa'), isFalse);
    expect(i18n.code, 'en');
    expect(await i18n.trySet('om'), isFalse);
    expect(await i18n.trySet('am'), isTrue);
    expect(i18n.code, 'am');
    expect(i18n.t('welcome.report'), isNot(equals('Tell us what happened')));
  });
}
