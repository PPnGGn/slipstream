import 'package:slipstream/features/routing/data/custom_rule.dart';
import 'package:slipstream/features/routing/data/custom_rule_value.dart';
import 'package:slipstream/l10n/l10n_context.dart';

/// Texts of the Custom rules list and its sheet, as pure functions: the page
/// only draws what these say, so they can be tested without a widget.

String ruleActionTitle(AppLocalizations l10n, RuleAction action) =>
    switch (action) {
      RuleAction.proxy => l10n.ruleProxy,
      RuleAction.direct => l10n.ruleDirect,
      RuleAction.block => l10n.ruleBlock,
    };

/// Under the action picker: what the chosen action does with the traffic.
String ruleActionHint(AppLocalizations l10n, RuleAction action) =>
    switch (action) {
      RuleAction.proxy => l10n.ruleProxyHint,
      RuleAction.direct => l10n.ruleDirectHint,
      RuleAction.block => l10n.ruleBlockHint,
    };

/// Shown under the field when a value is refused. Each says what to type
/// instead, not only what was wrong.
String ruleInputErrorText(AppLocalizations l10n, RuleInputError error) =>
    switch (error) {
      RuleInputError.empty => l10n.ruleErrEmpty,
      RuleInputError.invalid => l10n.ruleErrInvalid,
      // The zone is Cyrillic on purpose: it is the example of a name that
      // needs the xn-- form, and the translations stay free of it.
      RuleInputError.nonAscii => l10n.ruleErrNonAscii('.рф'),
      RuleInputError.badPrefix => l10n.ruleErrPrefix,
      RuleInputError.duplicate => l10n.ruleErrDuplicate,
    };

/// What a row says about its value, under the value itself.
String ruleKindLabel(AppLocalizations l10n, CustomRule rule) {
  if (!rule.isIp) return l10n.ruleKindDomain;
  return rule.value.contains('/') ? l10n.ruleKindRange : l10n.ruleKindIp;
}

/// The count shown in the Routing row of Settings; null with no rules.
String? customRulesSummary(AppLocalizations l10n, int count) =>
    count == 0 ? null : l10n.rulesCount(count);
