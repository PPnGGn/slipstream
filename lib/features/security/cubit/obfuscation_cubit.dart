import 'package:bloc/bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:slipstream/features/security/data/obfuscation_settings.dart';
import 'package:slipstream/features/security/data/obfuscation_store.dart';

/// State: the Fragment and Noise settings. They reach the core with the next
/// connect (see VpnRepository.buildConfigMessage), not while it runs.
@LazySingleton()
class ObfuscationCubit extends Cubit<ObfuscationSettings> {
  ObfuscationCubit({required ObfuscationStore store})
    : _store = store,
      super(store.load());

  final ObfuscationStore _store;

  Future<void> setFragmentEnabled({required bool enabled}) =>
      _set(state.copyWith(fragmentEnabled: enabled));

  Future<void> setNoiseEnabled({required bool enabled}) =>
      _set(state.copyWith(noiseEnabled: enabled));

  /// Saves [params] written the way xray reads them, or returns what is wrong
  /// with them and saves nothing.
  Future<FragmentErrors?> saveFragment(FragmentParams params) async {
    final errors = validateFragment(params);
    if (!errors.isValid) return errors;
    await _set(state.copyWith(fragment: params.normalized()));
    return null;
  }

  Future<NoiseErrors?> saveNoise(NoiseParams params) async {
    final errors = validateNoise(params);
    if (!errors.isValid) return errors;
    await _set(state.copyWith(noise: params.normalized()));
    return null;
  }

  Future<void> _set(ObfuscationSettings next) async {
    if (next == state) return;
    emit(next);
    await _store.save(next);
  }
}
