import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slipstream/features/language/data/app_language.dart';

/// The language picked on the Appearance page. Not set means "system".
@lazySingleton
class LanguageStore {
  static const _key = 'app_language';

  final SharedPreferences _prefs;

  LanguageStore(this._prefs);

  AppLanguage load() => AppLanguage.fromCode(_prefs.getString(_key));

  Future<void> save(AppLanguage language) =>
      _prefs.setString(_key, language.code);
}
