import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream/features/routing/data/custom_rule.dart';
import 'package:slipstream/features/routing/data/custom_rule_value.dart';
import 'package:slipstream/features/routing/ui/custom_rule_labels.dart';

void main() {
  CustomRule rule(String value) =>
      CustomRule(id: 'i', value: value, action: RuleAction.proxy);

  group('actions', () {
    test('every action has a title and a hint', () {
      for (final action in RuleAction.values) {
        expect(ruleActionTitle(action), isNotEmpty);
        expect(ruleActionHint(action), isNotEmpty);
      }
    });

    test('titles', () {
      expect(ruleActionTitle(RuleAction.proxy), 'Proxy');
      expect(ruleActionTitle(RuleAction.direct), 'Direct');
      expect(ruleActionTitle(RuleAction.block), 'Block');
    });

    test('the hint says where the traffic goes', () {
      expect(ruleActionHint(RuleAction.proxy), contains('through the VPN'));
      expect(ruleActionHint(RuleAction.direct), contains('bypassing the VPN'));
      expect(ruleActionHint(RuleAction.block), contains('dropped'));
    });
  });

  group('input errors', () {
    test('every error has a text', () {
      for (final error in RuleInputError.values) {
        expect(ruleInputErrorText(error), isNotEmpty);
      }
    });

    test('the texts tell what to do, not just what went wrong', () {
      expect(ruleInputErrorText(RuleInputError.nonAscii), contains('xn--'));
      expect(ruleInputErrorText(RuleInputError.badPrefix), contains('32'));
      expect(ruleInputErrorText(RuleInputError.badPrefix), contains('128'));
      expect(
        ruleInputErrorText(RuleInputError.invalid),
        contains('example.com'),
      );
    });
  });

  group('what a row says about its value', () {
    test('a domain', () {
      expect(ruleKindLabel(rule('example.com')), 'Domain and subdomains');
    });

    test('an address', () {
      expect(ruleKindLabel(rule('1.2.3.4')), 'IP address');
      expect(ruleKindLabel(rule('::1')), 'IP address');
    });

    test('a range', () {
      expect(ruleKindLabel(rule('10.0.0.0/8')), 'IP range');
      expect(ruleKindLabel(rule('2001:db8::/32')), 'IP range');
    });
  });

  group('customRulesSummary', () {
    test('nothing to say with no rules', () {
      expect(customRulesSummary(0), isNull);
    });

    test('counts, singular and plural', () {
      expect(customRulesSummary(1), '1 rule');
      expect(customRulesSummary(2), '2 rules');
      expect(customRulesSummary(12), '12 rules');
    });
  });
}
