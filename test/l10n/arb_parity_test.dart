import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The four translation files must stay in step: a key missing in one of
/// them would silently show English (or nothing) in that language.
void main() {
  const languages = ['en', 'ru', 'zh', 'fa'];

  Map<String, String> load(String language) {
    final raw =
        jsonDecode(File('lib/l10n/app_$language.arb').readAsStringSync())
            as Map<String, dynamic>;
    return {
      for (final entry in raw.entries)
        if (!entry.key.startsWith('@')) entry.key: entry.value as String,
    };
  }

  // Names of the {placeholders} of a message, ICU plural/select bodies
  // included (their branches never add a new top-level name).
  Set<String> placeholders(String message) => RegExp(
    r'\{\s*(\w+)\s*(?=[,}])',
  ).allMatches(message).map((m) => m.group(1)!).toSet();

  final messages = {for (final l in languages) l: load(l)};
  final english = messages['en']!;

  test('English, the template, has messages', () {
    expect(english, isNotEmpty);
  });

  for (final language in languages.skip(1)) {
    test('$language has exactly the keys of English', () {
      final keys = messages[language]!.keys.toSet();
      expect(
        english.keys.toSet().difference(keys),
        isEmpty,
        reason: 'missing in app_$language.arb',
      );
      expect(
        keys.difference(english.keys.toSet()),
        isEmpty,
        reason: 'unknown in app_$language.arb',
      );
    });

    test('$language uses the same placeholders as English', () {
      for (final entry in messages[language]!.entries) {
        final base = english[entry.key];
        if (base == null) continue;
        expect(
          placeholders(entry.value),
          placeholders(base),
          reason: '${entry.key} in app_$language.arb',
        );
      }
    });

    test('$language has no empty messages', () {
      for (final entry in messages[language]!.entries) {
        expect(entry.value.trim(), isNotEmpty, reason: entry.key);
      }
    });
  }

  test('English messages contain no Cyrillic, Arabic script or Chinese', () {
    final foreign = RegExp(r'[Ѐ-ӿ؀-ۿ一-鿿]');
    for (final entry in english.entries) {
      expect(foreign.hasMatch(entry.value), isFalse, reason: entry.key);
    }
  });
}
