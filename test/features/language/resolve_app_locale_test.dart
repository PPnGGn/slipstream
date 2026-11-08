import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream/features/language/data/app_language.dart';
import 'package:slipstream/features/language/data/resolve_app_locale.dart';

void main() {
  group('AppLanguage.fromCode', () {
    test('reads every stored code back', () {
      for (final language in AppLanguage.values) {
        expect(AppLanguage.fromCode(language.code), language);
      }
    });

    test('null and unknown codes mean system', () {
      expect(AppLanguage.fromCode(null), AppLanguage.system);
      expect(AppLanguage.fromCode('tr'), AppLanguage.system);
      expect(AppLanguage.fromCode(''), AppLanguage.system);
    });
  });

  group('resolveAppLocale with a chosen language', () {
    test('ignores the phone languages', () {
      expect(
        resolveAppLocale(AppLanguage.fa, const [Locale('ru')]),
        const Locale('fa'),
      );
      expect(
        resolveAppLocale(AppLanguage.en, const [Locale('ru')]),
        const Locale('en'),
      );
    });
  });

  group('resolveAppLocale with the system language', () {
    test('takes the first supported language of the phone', () {
      expect(
        resolveAppLocale(AppLanguage.system, const [
          Locale('de'),
          Locale('ru', 'RU'),
          Locale('en'),
        ]),
        const Locale('ru'),
      );
    });

    test('falls back to English when nothing is supported', () {
      expect(
        resolveAppLocale(AppLanguage.system, const [
          Locale('de'),
          Locale('tr'),
        ]),
        const Locale('en'),
      );
    });

    test('falls back to English for an empty list', () {
      expect(
        resolveAppLocale(AppLanguage.system, const []),
        const Locale('en'),
      );
    });

    test('every Chinese variant gets the one Chinese translation', () {
      expect(
        resolveAppLocale(AppLanguage.system, [
          const Locale.fromSubtags(
            languageCode: 'zh',
            scriptCode: 'Hant',
            countryCode: 'TW',
          ),
        ]),
        const Locale('zh'),
      );
      expect(
        resolveAppLocale(AppLanguage.system, const [Locale('zh', 'HK')]),
        const Locale('zh'),
      );
    });

    test('Persian is found by its language code', () {
      expect(
        resolveAppLocale(AppLanguage.system, const [Locale('fa', 'IR')]),
        const Locale('fa'),
      );
    });
  });

  test('only a chosen language is forced on the app', () {
    expect(AppLanguage.system.locale, isNull);
    expect(AppLanguage.ru.locale, const Locale('ru'));
  });
}
