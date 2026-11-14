import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slipstream/features/security/cubit/obfuscation_cubit.dart';
import 'package:slipstream/features/security/data/obfuscation_settings.dart';
import 'package:slipstream/features/security/data/obfuscation_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ObfuscationStore> storeWith(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    return ObfuscationStore(await SharedPreferences.getInstance());
  }

  test('starts with both options off for a fresh install', () async {
    final cubit = ObfuscationCubit(store: await storeWith({}));

    expect(cubit.state, equals(const ObfuscationSettings()));
  });

  test('starts from what the store holds', () async {
    final cubit = ObfuscationCubit(
      store: await storeWith({'fragment_enabled': true}),
    );

    expect(cubit.state.fragmentEnabled, isTrue);
  });

  test('setFragmentEnabled emits and stores', () async {
    final store = await storeWith({});
    final cubit = ObfuscationCubit(store: store);

    await cubit.setFragmentEnabled(enabled: true);

    expect(cubit.state.fragmentEnabled, isTrue);
    expect(store.load().fragmentEnabled, isTrue);
  });

  test('setNoiseEnabled emits and stores', () async {
    final store = await storeWith({});
    final cubit = ObfuscationCubit(store: store);

    await cubit.setNoiseEnabled(enabled: true);

    expect(cubit.state.noiseEnabled, isTrue);
    expect(store.load().noiseEnabled, isTrue);
  });

  test('a call that changes nothing emits nothing', () async {
    final cubit = ObfuscationCubit(store: await storeWith({}));
    final emitted = <ObfuscationSettings>[];
    final sub = cubit.stream.listen(emitted.add);

    await cubit.setFragmentEnabled(enabled: false);
    await cubit.setNoiseEnabled(enabled: false);
    await Future<void>.delayed(Duration.zero);

    expect(emitted, isEmpty);
    await sub.cancel();
  });

  group('saveFragment', () {
    test(
      'stores the normalized values and keeps the switch as it is',
      () async {
        final store = await storeWith({'fragment_enabled': true});
        final cubit = ObfuscationCubit(store: store);

        final errors = await cubit.saveFragment(
          const FragmentParams(
            packets: 'TLSHello',
            length: '120',
            delay: '5-9',
          ),
        );

        expect(errors, isNull);
        expect(cubit.state.fragment.packets, equals('tlshello'));
        expect(cubit.state.fragment.length, equals('120-120'));
        expect(cubit.state.fragmentEnabled, isTrue);
        expect(store.load().fragment.length, equals('120-120'));
      },
    );

    test('refuses invalid values and leaves the saved ones alone', () async {
      final store = await storeWith({});
      final cubit = ObfuscationCubit(store: store);

      final errors = await cubit.saveFragment(
        const FragmentParams(length: '0-10'),
      );

      expect(errors, isNotNull);
      expect(errors!.length, equals(RangeInputError.tooSmall));
      expect(cubit.state.fragment, equals(const FragmentParams()));
      expect(store.load().fragment, equals(const FragmentParams()));
    });
  });

  group('saveNoise', () {
    test('stores the normalized values', () async {
      final store = await storeWith({});
      final cubit = ObfuscationCubit(store: store);

      final errors = await cubit.saveNoise(
        const NoiseParams(size: '33', delay: '1-2'),
      );

      expect(errors, isNull);
      expect(cubit.state.noise.size, equals('33-33'));
      expect(store.load().noise.size, equals('33-33'));
    });

    test('refuses invalid values', () async {
      final cubit = ObfuscationCubit(store: await storeWith({}));

      final errors = await cubit.saveNoise(const NoiseParams(size: '9999'));

      expect(errors!.size, equals(RangeInputError.tooLarge));
      expect(cubit.state.noise, equals(const NoiseParams()));
    });
  });
}
