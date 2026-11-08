import 'dart:ui';

import 'package:slipstream/features/language/data/app_language.dart';

/// The languages the app has translations for, in the order of the
/// Appearance list. English is the fallback for everything else.
const supportedAppLocales = [
  Locale('en'),
  Locale('ru'),
  Locale('zh'),
  Locale('fa'),
];

/// Picks the language the app shows.
///
/// A language chosen by the user always wins. With [AppLanguage.system] the
/// first language of [deviceLocales] (the phone's list, best first) that we
/// have a translation for is used; nothing matches: English. Only the
/// language code is compared, so `zh_TW` and `zh_HK` get the one Chinese
/// translation, which is closer than English.
Locale resolveAppLocale(AppLanguage language, List<Locale> deviceLocales) {
  final forced = language.locale;
  if (forced != null) return forced;

  for (final device in deviceLocales) {
    for (final supported in supportedAppLocales) {
      if (supported.languageCode == device.languageCode) return supported;
    }
  }
  return supportedAppLocales.first;
}
