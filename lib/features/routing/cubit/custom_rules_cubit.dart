import 'package:bloc/bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:slipstream/features/routing/data/custom_rule.dart';
import 'package:slipstream/features/routing/data/custom_rule_value.dart';
import 'package:slipstream/features/routing/data/custom_rules_store.dart';
import 'package:uuid/uuid.dart';

/// Holds the Custom rules list, in the order the user added the rules. Read at
/// connect time (VpnRepository.start) and handed to RoutingPolicyGate, which
/// puts them in the config most specific first; a change takes effect on the
/// next connection, not while the tunnel runs.
///
/// [add] and [update] take what the user typed and answer with the reason it
/// was refused, or null when the list changed.
@LazySingleton()
class CustomRulesCubit extends Cubit<List<CustomRule>> {
  CustomRulesCubit({
    required CustomRulesStore store,
    @ignoreParam String Function()? newId,
  }) : _store = store,
       _newId = newId ?? (() => const Uuid().v4()),
       super(store.load());

  final CustomRulesStore _store;
  final String Function() _newId;

  Future<RuleInputError?> add(String input, RuleAction action) async {
    final (:value, :error) = parseRuleValue(input);
    if (value == null) return error;
    if (state.any((rule) => rule.value == value)) {
      return RuleInputError.duplicate;
    }
    await _apply([
      ...state,
      CustomRule(id: _newId(), value: value, action: action),
    ]);
    return null;
  }

  /// Changes the rule [id] in place: it keeps its id and its place in the list.
  Future<RuleInputError?> update(
    String id,
    String input,
    RuleAction action,
  ) async {
    final (:value, :error) = parseRuleValue(input);
    if (value == null) return error;
    final at = state.indexWhere((rule) => rule.id == id);
    if (at < 0) return null;
    if (state.any((rule) => rule.id != id && rule.value == value)) {
      return RuleInputError.duplicate;
    }
    final next = [...state];
    next[at] = state[at].copyWith(value: value, action: action);
    await _apply(next);
    return null;
  }

  Future<void> remove(String id) async {
    if (!state.any((rule) => rule.id == id)) return;
    await _apply([
      for (final rule in state)
        if (rule.id != id) rule,
    ]);
  }

  Future<void> _apply(List<CustomRule> next) async {
    emit(next);
    await _store.save(next);
  }
}
