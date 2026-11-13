import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slipstream/features/security/data/obfuscation_settings.dart';
import 'package:slipstream/features/security/data/obfuscation_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ObfuscationStore> storeWith(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    return ObfuscationStore(await SharedPreferences.getInstance());
  }

  test('a fresh install has both options off and the default values', () async {
    final store = await storeWith({});

    expect(store.load(), equals(const ObfuscationSettings()));
  });

  test('save round-trips every field', () async {
    final store = await storeWith({});
    const settings = ObfuscationSettings(
      fragmentEnabled: true,
      fragment: FragmentParams(packets: '1-3', length: '50-90', delay: '5-9'),
      noiseEnabled: true,
      noise: NoiseParams(size: '30-40', delay: '2-3'),
    );

    await store.save(settings);

    expect(store.load(), equals(settings));
  });

  test('is stored under the documented keys', () async {
    final store = await storeWith({});
    await store.save(
      const ObfuscationSettings(
        fragmentEnabled: true,
        fragment: FragmentParams(packets: '1-3', length: '50-90', delay: '5-9'),
        noiseEnabled: true,
        noise: NoiseParams(size: '30-40', delay: '2-3'),
      ),
    );

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('fragment_enabled'), isTrue);
    expect(prefs.getString('fragment_packets'), equals('1-3'));
    expect(prefs.getString('fragment_length'), equals('50-90'));
    expect(prefs.getString('fragment_delay'), equals('5-9'));
    expect(prefs.getBool('noise_enabled'), isTrue);
    expect(prefs.getString('noise_size'), equals('30-40'));
    expect(prefs.getString('noise_delay'), equals('2-3'));
  });

  test('a value that fails validation falls back to the default', () async {
    final store = await storeWith({
      'fragment_enabled': true,
      'fragment_length': '0-0',
      'noise_enabled': true,
      'noise_size': 'abc',
    });

    final settings = store.load();

    expect(settings.fragmentEnabled, isTrue);
    expect(settings.fragment.length, equals(const FragmentParams().length));
    expect(settings.noiseEnabled, isTrue);
    expect(settings.noise.size, equals(const NoiseParams().size));
  });

  test('one bad field does not take the good ones with it', () async {
    final store = await storeWith({
      'fragment_length': '0-0',
      'fragment_delay': '7-8',
    });

    expect(store.load().fragment.delay, equals('7-8'));
  });
}
