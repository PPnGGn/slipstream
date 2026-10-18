import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slipstream/features/routing/cubit/ad_block_cubit.dart';
import 'package:slipstream/features/routing/data/ad_block_mode.dart';
import 'package:slipstream/features/routing/data/ad_block_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AdBlockStore> storeWith(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    return AdBlockStore(await SharedPreferences.getInstance());
  }

  group('full list not allowed (iOS: the tunnel extension has a 50 MB cap)', () {
    test('a stored full mode loads as basic', () async {
      final store = await storeWith({'ad_block_mode': 'full'});
      final cubit = AdBlockCubit(store: store, fullAllowed: false);
      expect(cubit.state, AdBlockMode.basic);
    });

    test('a legacy enabled flag loads as basic', () async {
      final store = await storeWith({'ad_block_enabled': true});
      final cubit = AdBlockCubit(store: store, fullAllowed: false);
      expect(cubit.state, AdBlockMode.basic);
    });

    test('setMode(full) turns on basic and stores it', () async {
      final store = await storeWith({});
      final cubit = AdBlockCubit(store: store, fullAllowed: false);
      await cubit.setMode(AdBlockMode.full);
      expect(cubit.state, AdBlockMode.basic);
      expect(store.load(), AdBlockMode.basic);
    });

    test('the switch turns on basic', () async {
      final store = await storeWith({});
      final cubit = AdBlockCubit(store: store, fullAllowed: false);
      await cubit.setEnabled(enabled: true);
      expect(cubit.state, AdBlockMode.basic);
    });

    test('off stays off', () async {
      final store = await storeWith({});
      final cubit = AdBlockCubit(store: store, fullAllowed: false);
      expect(cubit.state, AdBlockMode.off);
      expect(cubit.fullAllowed, isFalse);
    });
  });

  group('full list allowed (Android)', () {
    test('a stored full mode stays full', () async {
      final store = await storeWith({'ad_block_mode': 'full'});
      final cubit = AdBlockCubit(store: store, fullAllowed: true);
      expect(cubit.state, AdBlockMode.full);
      expect(cubit.fullAllowed, isTrue);
    });

    test('the switch turns on full', () async {
      final store = await storeWith({});
      final cubit = AdBlockCubit(store: store, fullAllowed: true);
      await cubit.setEnabled(enabled: true);
      expect(cubit.state, AdBlockMode.full);
    });

    test('basic can still be picked', () async {
      final store = await storeWith({});
      final cubit = AdBlockCubit(store: store, fullAllowed: true);
      await cubit.setMode(AdBlockMode.basic);
      expect(cubit.state, AdBlockMode.basic);
      expect(store.load(), AdBlockMode.basic);
    });
  });
}
