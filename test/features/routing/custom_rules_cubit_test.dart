import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slipstream/features/routing/cubit/custom_rules_cubit.dart';
import 'package:slipstream/features/routing/data/custom_rule.dart';
import 'package:slipstream/features/routing/data/custom_rule_value.dart';
import 'package:slipstream/features/routing/data/custom_rules_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<CustomRulesStore> storeWith(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    return CustomRulesStore(await SharedPreferences.getInstance());
  }

  Future<(CustomRulesCubit, CustomRulesStore)> make([
    List<CustomRule> initial = const [],
  ]) async {
    final store = await storeWith({});
    if (initial.isNotEmpty) await store.save(initial);
    var n = 0;
    final cubit = CustomRulesCubit(store: store, newId: () => 'id${++n}');
    return (cubit, store);
  }

  group('add', () {
    test('starts empty on a fresh install', () async {
      final (cubit, _) = await make();
      expect(cubit.state, isEmpty);
    });

    test('starts from what the store holds', () async {
      const saved = CustomRule(
        id: 's',
        value: 'a.com',
        action: RuleAction.proxy,
      );
      final (cubit, _) = await make([saved]);
      expect(cubit.state, [saved]);
    });

    test('a valid rule is added, normalised and stored', () async {
      final (cubit, store) = await make();
      final error = await cubit.add(
        '  HTTPS://Example.com/x ',
        RuleAction.direct,
      );
      expect(error, isNull);
      const expected = CustomRule(
        id: 'id1',
        value: 'example.com',
        action: RuleAction.direct,
      );
      expect(cubit.state, [expected]);
      expect(store.load(), [expected]);
    });

    test('rules stay in the order they were added', () async {
      final (cubit, _) = await make();
      await cubit.add('b.com', RuleAction.proxy);
      await cubit.add('a.com', RuleAction.block);
      expect(cubit.state.map((r) => r.value), ['b.com', 'a.com']);
    });

    test('an invalid value gives the error and changes nothing', () async {
      final (cubit, store) = await make();
      expect(await cubit.add('', RuleAction.proxy), RuleInputError.empty);
      expect(
        await cubit.add('привет.рф', RuleAction.proxy),
        RuleInputError.nonAscii,
      );
      expect(
        await cubit.add('10.0.0.0/40', RuleAction.proxy),
        RuleInputError.badPrefix,
      );
      expect(
        await cubit.add('geosite:ru', RuleAction.proxy),
        RuleInputError.invalid,
      );
      expect(cubit.state, isEmpty);
      expect(store.load(), isEmpty);
    });

    test(
      'the same value again is a duplicate, even with another action',
      () async {
        final (cubit, _) = await make();
        await cubit.add('example.com', RuleAction.direct);
        expect(
          await cubit.add('WWW.example.com', RuleAction.proxy),
          isNull,
          reason: 'a subdomain is a different rule',
        );
        expect(
          await cubit.add('https://example.com/', RuleAction.block),
          RuleInputError.duplicate,
        );
        expect(cubit.state, hasLength(2));
      },
    );
  });

  group('update', () {
    test(
      'changes the value and the action, keeps the id and the place',
      () async {
        final (cubit, store) = await make();
        await cubit.add('a.com', RuleAction.proxy);
        await cubit.add('b.com', RuleAction.proxy);
        final error = await cubit.update('id1', 'c.com', RuleAction.block);
        expect(error, isNull);
        expect(cubit.state.map((r) => (r.id, r.value, r.action)), [
          ('id1', 'c.com', RuleAction.block),
          ('id2', 'b.com', RuleAction.proxy),
        ]);
        expect(store.load(), cubit.state);
      },
    );

    test('saving a rule with its own value is not a duplicate', () async {
      final (cubit, _) = await make();
      await cubit.add('a.com', RuleAction.proxy);
      expect(await cubit.update('id1', 'a.com', RuleAction.direct), isNull);
      expect(cubit.state.single.action, RuleAction.direct);
    });

    test('a value another rule already has is a duplicate', () async {
      final (cubit, _) = await make();
      await cubit.add('a.com', RuleAction.proxy);
      await cubit.add('b.com', RuleAction.proxy);
      expect(
        await cubit.update('id2', 'a.com', RuleAction.block),
        RuleInputError.duplicate,
      );
      expect(cubit.state.map((r) => r.value), ['a.com', 'b.com']);
    });

    test('an invalid value gives the error and changes nothing', () async {
      final (cubit, store) = await make();
      await cubit.add('a.com', RuleAction.proxy);
      expect(
        await cubit.update('id1', '', RuleAction.block),
        RuleInputError.empty,
      );
      expect(cubit.state.single.value, 'a.com');
      expect(store.load().single.value, 'a.com');
    });

    test('an unknown id changes nothing', () async {
      final (cubit, _) = await make();
      await cubit.add('a.com', RuleAction.proxy);
      await cubit.update('nope', 'z.com', RuleAction.block);
      expect(cubit.state.single.value, 'a.com');
    });
  });

  group('remove', () {
    test('drops the rule from the state and the store', () async {
      final (cubit, store) = await make();
      await cubit.add('a.com', RuleAction.proxy);
      await cubit.add('b.com', RuleAction.proxy);
      await cubit.remove('id1');
      expect(cubit.state.map((r) => r.value), ['b.com']);
      expect(store.load().map((r) => r.value), ['b.com']);
    });

    test('an unknown id emits nothing', () async {
      final (cubit, _) = await make();
      await cubit.add('a.com', RuleAction.proxy);
      final emitted = <List<CustomRule>>[];
      final sub = cubit.stream.listen(emitted.add);
      await cubit.remove('nope');
      await Future<void>.delayed(Duration.zero);
      expect(emitted, isEmpty);
      await sub.cancel();
    });

    test('the freed value can be added again', () async {
      final (cubit, _) = await make();
      await cubit.add('a.com', RuleAction.proxy);
      await cubit.remove('id1');
      expect(await cubit.add('a.com', RuleAction.block), isNull);
    });
  });
}
