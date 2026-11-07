import 'package:slipstream/features/routing/data/custom_rule.dart';
import 'package:slipstream/features/routing/data/custom_rule_value.dart';

/// Texts of the Custom rules list and its sheet, as pure functions: the page
/// only draws what these say, so they can be tested without a widget.

String ruleActionTitle(RuleAction action) => switch (action) {
  RuleAction.proxy => 'Proxy',
  RuleAction.direct => 'Direct',
  RuleAction.block => 'Block',
};

/// Under the action picker: what the chosen action does with the traffic.
String ruleActionHint(RuleAction action) => switch (action) {
  RuleAction.proxy => 'Always sent through the VPN',
  RuleAction.direct => 'Always sent directly, bypassing the VPN',
  RuleAction.block => 'Connections are dropped',
};

/// Shown under the field when a value is refused. Each says what to type
/// instead, not only what was wrong.
String ruleInputErrorText(RuleInputError error) => switch (error) {
  RuleInputError.empty => 'Type a domain or an IP address',
  RuleInputError.invalid =>
    'Not a domain or an IP address. Try example.com or 1.2.3.0/24',
  RuleInputError.nonAscii =>
    'Use the xn-- form of the name, e.g. xn--p1ai for .рф',
  RuleInputError.badPrefix =>
    'The range prefix is 0–32 for IPv4 and 0–128 for IPv6',
  RuleInputError.duplicate => 'There is already a rule for this value',
};

/// What a row says about its value, under the value itself.
String ruleKindLabel(CustomRule rule) {
  if (!rule.isIp) return 'Domain and subdomains';
  return rule.value.contains('/') ? 'IP range' : 'IP address';
}

/// The count shown in the Routing row of Settings; null with no rules.
String? customRulesSummary(int count) => switch (count) {
  0 => null,
  1 => '1 rule',
  _ => '$count rules',
};

/// The notice on the Routing page while the selected server has a routing of
/// its own.
const routingOwnConfigNotice =
    'The selected server brings its own routing, so RU bypass, ad blocking '
    'and LAN bypass do not apply to it. Your custom rules do.';
