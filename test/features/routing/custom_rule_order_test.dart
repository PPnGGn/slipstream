import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream/features/routing/data/custom_rule.dart';
import 'package:slipstream/features/routing/data/custom_rule_order.dart';

void main() {
  CustomRule r(String value, [RuleAction action = RuleAction.proxy]) =>
      CustomRule(id: value, value: value, action: action);

  List<String> order(List<String> values) =>
      orderForConfig(values.map(r).toList()).map((e) => e.value).toList();

  test('nothing in, nothing out', () {
    expect(orderForConfig(const []), isEmpty);
  });

  test('a subdomain goes before its domain', () {
    expect(order(['google.com', 'mail.google.com']), [
      'mail.google.com',
      'google.com',
    ]);
  });

  test('more labels first, whatever the order they were added in', () {
    expect(order(['a.com', 'x.y.b.com', 'z.b.com']), [
      'x.y.b.com',
      'z.b.com',
      'a.com',
    ]);
  });

  test('domains go before addresses', () {
    expect(order(['10.0.0.0/8', 'example.com', '1.2.3.4']), [
      'example.com',
      '1.2.3.4',
      '10.0.0.0/8',
    ]);
  });

  test(
    'a longer prefix goes first; a plain address counts as a full prefix',
    () {
      expect(order(['10.0.0.0/8', '10.1.0.0/16', '10.1.2.3', '10.1.2.0/24']), [
        '10.1.2.3',
        '10.1.2.0/24',
        '10.1.0.0/16',
        '10.0.0.0/8',
      ]);
    },
  );

  test('IPv6 ranges are ordered by prefix too', () {
    expect(order(['2001:db8::/32', '2001:db8:1::/48', '::1']), [
      '::1',
      '2001:db8:1::/48',
      '2001:db8::/32',
    ]);
  });

  test('equal specificity keeps the order the rules were added in', () {
    expect(order(['b.com', 'a.com', 'c.com']), ['b.com', 'a.com', 'c.com']);
    expect(order(['10.0.0.0/8', '11.0.0.0/8']), ['10.0.0.0/8', '11.0.0.0/8']);
  });

  test('the input list is not changed', () {
    final input = [r('google.com'), r('mail.google.com')];
    orderForConfig(input);
    expect(input.map((e) => e.value), ['google.com', 'mail.google.com']);
  });

  test('the action does not affect the order', () {
    final ordered = orderForConfig([
      r('google.com', RuleAction.direct),
      r('mail.google.com', RuleAction.proxy),
    ]);
    expect(ordered.map((e) => e.action), [RuleAction.proxy, RuleAction.direct]);
  });
}
