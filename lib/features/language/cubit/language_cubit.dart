import 'package:bloc/bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:slipstream/features/language/data/app_language.dart';
import 'package:slipstream/features/language/data/language_store.dart';

/// State: the language the user chose ([AppLanguage.system] by default).
/// MainApp rebuilds the MaterialApp from it, so a change repaints at once.
@LazySingleton()
class LanguageCubit extends Cubit<AppLanguage> {
  LanguageCubit({required LanguageStore store})
    : _store = store,
      super(store.load());

  final LanguageStore _store;

  Future<void> setLanguage(AppLanguage language) async {
    if (language == state) return;
    emit(language);
    await _store.save(language);
  }
}
