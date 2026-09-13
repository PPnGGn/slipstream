import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slipstream/features/diagnostics/data/memory_monitor_mode.dart';
import 'package:slipstream/features/diagnostics/data/memory_monitor_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<MemoryMonitorStore> storeWith(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    return MemoryMonitorStore(await SharedPreferences.getInstance());
  }

  test('fresh install defaults to off', () async {
    final store = await storeWith({});
    expect(store.load(), MemoryMonitorMode.off);
  });

  test('save round-trips', () async {
    final store = await storeWith({});
    await store.save(MemoryMonitorMode.on);
    expect(store.load(), MemoryMonitorMode.on);
  });

  test('an unknown stored value falls back to off', () async {
    final store = await storeWith({'memory_monitor_mode': 'wat'});
    expect(store.load(), MemoryMonitorMode.off);
  });
}
