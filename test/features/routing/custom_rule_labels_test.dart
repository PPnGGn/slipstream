import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream/features/routing/data/custom_rule.dart';
import 'package:slipstream/features/routing/data/custom_rule_value.dart';
import 'package:slipstream/features/routing/ui/custom_rule_labels.dart';

import '../../helpers/l10n.dart';

void main() {
  CustomRule rule(String value) =>
      CustomRule(id: 'i', value: value, action: RuleAction.proxy);

  group('actions', () {
    test('every action has a title and a hint', () {
      for (final action in RuleAction.values) {
        expect(ruleActionTitle(l10nEn, action), isNotEmpty);
        expect(ruleActionHint(l10nEn, action), isNotEmpty);
      }
    });

    test('titles', () {
      expect(ruleActionTitle(l10nEn, RuleAction.proxy), 'Proxy');
      expect(ruleActionTitle(l10nEn, RuleAction.direct), 'Direct');
      expect(ruleActionTitle(l10nEn, RuleAction.block), 'Block');
    });

    test('the hint says where the traffic goes', () {
      expect(
        ruleActionHint(l10nEn, RuleAction.proxy),
        contains('through the VPN'),
      );
      expect(
        ruleActionHint(l10nEn, RuleAction.direct),
        contains('bypassing the VPN'),
      );
      expect(ruleActionHint(l10nEn, RuleAction.block), contains('dropped'));
    });
  });

  group('input errors', () {
    test('every error has a text', () {
      for (final error in RuleInputError.values) {
        expect(ruleInputErrorText(l10nEn, error), isNotEmpty);
      }
    });

    test('the texts tell what to do, not just what went wrong', () {
      expect(
        ruleInputErrorText(l10nEn, RuleInputError.nonAscii),
        contains('xn--'),
      );
      expect(
        ruleInputErrorText(l10nEn, RuleInputError.badPrefix),
        contains('32'),
      );
      expect(
        ruleInputErrorText(l10nEn, RuleInputError.badPrefix),
        contains('128'),
      );
      expect(
        ruleInputErrorText(l10nEn, RuleInputError.invalid),
        contains('example.com'),
      );
    });
  });

  group('what a row says about its value', () {
    test('a domain', () {
      expect(
        ruleKindLabel(l10nEn, rule('example.com')),
        'Domain and subdomains',
      );
    });

    test('an address', () {
      expect(ruleKindLabel(l10nEn, rule('1.2.3.4')), 'IP address');
      expect(ruleKindLabel(l10nEn, rule('::1')), 'IP address');
    });

    test('a range', () {
      expect(ruleKindLabel(l10nEn, rule('10.0.0.0/8')), 'IP range');
      expect(ruleKindLabel(l10nEn, rule('2001:db8::/32')), 'IP range');
    });
  });

  group('customRulesSummary', () {
    test('nothing to say with no rules', () {
      expect(customRulesSummary(l10nEn, 0), isNull);
    });

    test('counts, singular and plural', () {
      expect(customRulesSummary(l10nEn, 1), '1 rule');
      expect(customRulesSummary(l10nEn, 2), '2 rules');
      expect(customRulesSummary(l10nEn, 12), '12 rules');
    });
  });
}
