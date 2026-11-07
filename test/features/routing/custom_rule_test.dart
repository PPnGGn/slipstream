import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream/features/routing/data/custom_rule.dart';

void main() {
  group('RuleAction', () {
    test('tryParse finds the action by its name', () {
      expect(RuleAction.tryParse('proxy'), RuleAction.proxy);
      expect(RuleAction.tryParse('direct'), RuleAction.direct);
      expect(RuleAction.tryParse('block'), RuleAction.block);
    });

    test('tryParse gives null for anything else', () {
      expect(RuleAction.tryParse(null), isNull);
      expect(RuleAction.tryParse('other'), isNull);
      expect(RuleAction.tryParse(''), isNull);
    });
  });

  group('CustomRule', () {
    const rule = CustomRule(
      id: 'a1',
      value: 'example.com',
      action: RuleAction.direct,
    );

    test('JSON round-trips', () {
      expect(CustomRule.tryFromJson(rule.toJson()), rule);
    });

    test('JSON shape is the documented one', () {
      expect(rule.toJson(), {
        'id': 'a1',
        'value': 'example.com',
        'action': 'direct',
      });
    });

    test('isIp tells addresses and ranges from domains', () {
      expect(rule.isIp, isFalse);
      expect(rule.copyWith(value: '1.2.3.4').isIp, isTrue);
      expect(rule.copyWith(value: '10.0.0.0/8').isIp, isTrue);
      expect(rule.copyWith(value: '2001:db8::/32').isIp, isTrue);
    });

    test('copyWith changes only what it is given', () {
      final changed = rule.copyWith(action: RuleAction.block);
      expect(changed.id, 'a1');
      expect(changed.value, 'example.com');
      expect(changed.action, RuleAction.block);
    });

    test('equal by id, value and action', () {
      expect(
        rule,
        const CustomRule(
          id: 'a1',
          value: 'example.com',
          action: RuleAction.direct,
        ),
      );
      expect(rule == rule.copyWith(action: RuleAction.proxy), isFalse);
      expect(rule == rule.copyWith(id: 'b2'), isFalse);
    });

    group('tryFromJson', () {
      test('a value is brought to the normal form', () {
        final r = CustomRule.tryFromJson({
          'id': 'x',
          'value': 'WWW.Example.COM.',
          'action': 'proxy',
        });
        expect(r?.value, 'www.example.com');
      });

      test('null for a wrong shape', () {
        expect(CustomRule.tryFromJson(null), isNull);
        expect(CustomRule.tryFromJson('text'), isNull);
        expect(CustomRule.tryFromJson(<String, dynamic>{}), isNull);
        expect(
          CustomRule.tryFromJson({
            'id': 1,
            'value': 'a.com',
            'action': 'proxy',
          }),
          isNull,
        );
      });

      test('null for an unknown action', () {
        expect(
          CustomRule.tryFromJson({
            'id': 'x',
            'value': 'a.com',
            'action': 'reject',
          }),
          isNull,
        );
      });

      test('null for a value that is not valid', () {
        expect(
          CustomRule.tryFromJson({
            'id': 'x',
            'value': 'geosite:ru',
            'action': 'proxy',
          }),
          isNull,
        );
      });

      test('null for an empty id', () {
        expect(
          CustomRule.tryFromJson({
            'id': '',
            'value': 'a.com',
            'action': 'proxy',
          }),
          isNull,
        );
      });
    });
  });
}
