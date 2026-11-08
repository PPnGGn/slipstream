import 'dart:ui';

/// What the user picked in Settings → Appearance → Language.
///
/// [system] is the default: the app follows the phone (see resolveAppLocale).
/// The other values force one language. [code] is what is stored on disk, so
/// never rename it.
enum AppLanguage {
  system('system', null),
  en('en', Locale('en')),
  ru('ru', Locale('ru')),
  zh('zh', Locale('zh')),
  fa('fa', Locale('fa'));

  const AppLanguage(this.code, this.locale);

  final String code;

  /// The language to force on the app, or null to follow the phone.
  final Locale? locale;

  /// Reads a stored code; a missing or unknown one (for example a language
  /// dropped in a later version) means [system].
  static AppLanguage fromCode(String? code) {
    for (final language in values) {
      if (language.code == code) return language;
    }
    return system;
  }
}
