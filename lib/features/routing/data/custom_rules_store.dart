import 'dart:convert';

import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slipstream/features/routing/data/custom_rule.dart';

/// Keeps the Custom rules list in SharedPreferences, as one JSON list in the
/// order the user sees it. Anything unreadable reads as "no rules" or is
/// skipped entry by entry: a broken file must not stop the VPN from starting.
@lazySingleton
class CustomRulesStore {
  static const _key = 'routing_custom_rules';

  final SharedPreferences _prefs;

  CustomRulesStore(this._prefs);

  List<CustomRule> load() {
    final raw = _prefs.getString(_key);
    if (raw == null) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final seen = <String>{};
      return [
        for (final entry in decoded)
          if (CustomRule.tryFromJson(entry) case final rule?
              when seen.add(rule.value))
            rule,
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<void> save(List<CustomRule> rules) => _prefs.setString(
    _key,
    jsonEncode([for (final rule in rules) rule.toJson()]),
  );
}
