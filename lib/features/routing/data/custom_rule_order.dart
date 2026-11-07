import 'package:slipstream/features/routing/data/custom_rule.dart';
import 'package:slipstream/features/routing/data/custom_rule_value.dart';

/// The rules in the order they must stand in the xray config, where the first
/// match wins: the most specific first, so `mail.google.com → proxy` beats
/// `google.com → direct` without the user having to arrange them.
///  - domains before addresses;
///  - among domains, more labels first (`mail.google.com` before `google.com`);
///  - among addresses, the longer prefix first (`/32` before `/24` before `/8`);
///  - equal specificity keeps the order the rules were added in.
/// Returns a new list; [rules] stays in the order the user sees.
List<CustomRule> orderForConfig(List<CustomRule> rules) {
  final keyed = [
    for (var i = 0; i < rules.length; i++)
      (index: i, rule: rules[i], key: _specificity(rules[i])),
  ];
  keyed.sort((a, b) {
    final byGroup = a.key.group.compareTo(b.key.group);
    if (byGroup != 0) return byGroup;
    final bySpecificity = b.key.detail.compareTo(a.key.detail);
    if (bySpecificity != 0) return bySpecificity;
    return a.index.compareTo(b.index);
  });
  return [for (final k in keyed) k.rule];
}

/// `group` 0 is a domain, 1 an address; `detail` is how narrow the rule is
/// inside its group (labels in a domain, prefix length of an address).
({int group, int detail}) _specificity(CustomRule rule) {
  final ip = parseIpValue(rule.value);
  if (ip != null) return (group: 1, detail: ip.prefix);
  return (group: 0, detail: rule.value.split('.').length);
}
