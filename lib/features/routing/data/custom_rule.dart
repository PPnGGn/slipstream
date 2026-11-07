import 'package:flutter/foundation.dart';
import 'package:slipstream/features/routing/data/custom_rule_value.dart';

/// Where traffic that matches a [CustomRule] goes.
enum RuleAction {
  /// Through the VPN server.
  proxy,

  /// Straight out, bypassing the VPN.
  direct,

  /// Dropped.
  block;

  /// The action called [name], or null for anything unknown.
  static RuleAction? tryParse(String? name) {
    for (final action in values) {
      if (action.name == name) return action;
    }
    return null;
  }
}

/// One rule of the Custom rules list: a domain (with its subdomains) or an IP
/// address / range, and where its traffic goes. [value] is always in the form
/// [parseRuleValue] gives.
@immutable
class CustomRule {
  const CustomRule({
    required this.id,
    required this.value,
    required this.action,
  });

  /// Stable across edits, so the list can find the rule being edited.
  final String id;
  final String value;
  final RuleAction action;

  /// Whether the value is an IP address or range rather than a domain.
  bool get isIp => parseIpValue(value) != null;

  CustomRule copyWith({String? id, String? value, RuleAction? action}) =>
      CustomRule(
        id: id ?? this.id,
        value: value ?? this.value,
        action: action ?? this.action,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'value': value,
    'action': action.name,
  };

  /// The rule written by [toJson], or null if [json] is not one: wrong shape,
  /// no id, unknown action, or a value [parseRuleValue] refuses. A stored
  /// value is parsed again, so an older or hand-edited one comes out in the
  /// normal form.
  static CustomRule? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final value = json['value'];
    final action = json['action'];
    if (id is! String || id.isEmpty) return null;
    if (value is! String || action is! String) return null;
    final parsedAction = RuleAction.tryParse(action);
    if (parsedAction == null) return null;
    final parsedValue = parseRuleValue(value).value;
    if (parsedValue == null) return null;
    return CustomRule(id: id, value: parsedValue, action: parsedAction);
  }

  @override
  bool operator ==(Object other) =>
      other is CustomRule &&
      other.id == id &&
      other.value == value &&
      other.action == action;

  @override
  int get hashCode => Object.hash(id, value, action);

  @override
  String toString() => 'CustomRule($id, $value, ${action.name})';
}
