import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slipstream/features/routing/data/custom_rule.dart';
import 'package:slipstream/features/routing/data/custom_rules_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<CustomRulesStore> storeWith(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    return CustomRulesStore(await SharedPreferences.getInstance());
  }

  const a = CustomRule(
    id: 'a',
    value: 'example.com',
    action: RuleAction.direct,
  );
  const b = CustomRule(id: 'b', value: '10.1.0.0/16', action: RuleAction.block);

  test('no rules on a fresh install', () async {
    final store = await storeWith({});
    expect(store.load(), isEmpty);
  });

  test('save round-trips, order kept', () async {
    final store = await storeWith({});
    await store.save([b, a]);
    expect(store.load(), [b, a]);
  });

  test('an empty list round-trips', () async {
    final store = await storeWith({});
    await store.save([a]);
    await store.save(const []);
    expect(store.load(), isEmpty);
  });

  test('is stored under the documented key as a JSON list', () async {
    final store = await storeWith({});
    await store.save([a]);
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('routing_custom_rules');
    expect(raw, isNotNull);
    expect(jsonDecode(raw!), [
      {'id': 'a', 'value': 'example.com', 'action': 'direct'},
    ]);
  });

  test('broken JSON reads as no rules', () async {
    final store = await storeWith({'routing_custom_rules': '{not json'});
    expect(store.load(), isEmpty);
  });

  test('JSON that is not a list reads as no rules', () async {
    final store = await storeWith({'routing_custom_rules': '{"a": 1}'});
    expect(store.load(), isEmpty);
  });

  test('a bad entry is skipped, the good ones stay', () async {
    final store = await storeWith({
      'routing_custom_rules': jsonEncode([
        {'id': 'a', 'value': 'example.com', 'action': 'direct'},
        {
          'id': 'x',
          'value': 'example.org',
          'action': 'reject',
        }, // unknown action
        {'id': 'y', 'value': 'geosite:ru', 'action': 'proxy'}, // invalid value
        'garbage',
        {'id': 'b', 'value': '10.1.0.0/16', 'action': 'block'},
      ]),
    });
    expect(store.load(), [a, b]);
  });

  test('a repeated value is dropped, the first one wins', () async {
    final store = await storeWith({
      'routing_custom_rules': jsonEncode([
        {'id': 'a', 'value': 'example.com', 'action': 'direct'},
        {'id': 'c', 'value': 'EXAMPLE.com', 'action': 'block'},
      ]),
    });
    expect(store.load(), [a]);
  });
}
