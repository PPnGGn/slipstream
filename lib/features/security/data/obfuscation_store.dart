import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slipstream/features/security/data/obfuscation_settings.dart';

/// Keeps the Fragment and Noise settings. Both are off on a fresh install. A
/// field that fails validation (an old build wrote it, or the file was edited)
/// reads as its default, one field at a time, so a bad value never reaches xray
/// and never costs the good ones.
@lazySingleton
class ObfuscationStore {
  static const _fragmentEnabled = 'fragment_enabled';
  static const _fragmentPackets = 'fragment_packets';
  static const _fragmentLength = 'fragment_length';
  static const _fragmentDelay = 'fragment_delay';
  static const _noiseEnabled = 'noise_enabled';
  static const _noiseSize = 'noise_size';
  static const _noiseDelay = 'noise_delay';

  final SharedPreferences _prefs;

  ObfuscationStore(this._prefs);

  ObfuscationSettings load() {
    const fragment = FragmentParams();
    const noise = NoiseParams();
    return ObfuscationSettings(
      fragmentEnabled: _prefs.getBool(_fragmentEnabled) ?? false,
      fragment: FragmentParams(
        packets: _text(
          _fragmentPackets,
          fragment.packets,
          validateFragmentPackets,
        ),
        length: _text(_fragmentLength, fragment.length, validateFragmentLength),
        delay: _text(_fragmentDelay, fragment.delay, validateDelay),
      ),
      noiseEnabled: _prefs.getBool(_noiseEnabled) ?? false,
      noise: NoiseParams(
        size: _text(_noiseSize, noise.size, validateNoiseSize),
        delay: _text(_noiseDelay, noise.delay, validateDelay),
      ),
    );
  }

  Future<void> save(ObfuscationSettings settings) async {
    await _prefs.setBool(_fragmentEnabled, settings.fragmentEnabled);
    await _prefs.setString(_fragmentPackets, settings.fragment.packets);
    await _prefs.setString(_fragmentLength, settings.fragment.length);
    await _prefs.setString(_fragmentDelay, settings.fragment.delay);
    await _prefs.setBool(_noiseEnabled, settings.noiseEnabled);
    await _prefs.setString(_noiseSize, settings.noise.size);
    await _prefs.setString(_noiseDelay, settings.noise.delay);
  }

  String _text(
    String key,
    String fallback,
    RangeInputError? Function(String) validate,
  ) {
    final stored = _prefs.getString(key);
    return stored != null && validate(stored) == null ? stored : fallback;
  }
}
