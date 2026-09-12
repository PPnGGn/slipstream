import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slipstream/features/routing/data/ad_block_mode.dart';
import 'package:slipstream/features/routing/data/ad_block_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AdBlockStore> storeWith(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    return AdBlockStore(await SharedPreferences.getInstance());
  }

  test('fresh install defaults to off', () async {
    final store = await storeWith({});
    expect(store.load(), AdBlockMode.off);
  });

  test('legacy ad_block_enabled=true migrates to full', () async {
    final store = await storeWith({'ad_block_enabled': true});
    expect(store.load(), AdBlockMode.full);
  });

  test('legacy ad_block_enabled=false is off', () async {
    final store = await storeWith({'ad_block_enabled': false});
    expect(store.load(), AdBlockMode.off);
  });

  test('the new key wins over the legacy flag', () async {
    final store = await storeWith({
      'ad_block_enabled': true,
      'ad_block_mode': 'basic',
    });
    expect(store.load(), AdBlockMode.basic);
  });

  test('save round-trips through the new key', () async {
    final store = await storeWith({});
    await store.save(AdBlockMode.full);
    expect(store.load(), AdBlockMode.full);
  });

  test('an unknown stored value falls back to off', () async {
    final store = await storeWith({'ad_block_mode': 'wat'});
    expect(store.load(), AdBlockMode.off);
  });
}
