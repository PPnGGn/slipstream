import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream/features/security/data/obfuscation_settings.dart';
import 'package:slipstream/features/security/ui/obfuscation_labels.dart';

import '../../helpers/l10n.dart';

void main() {
  group('fragmentSubtitle', () {
    test('off: says it is off and what it would do', () {
      final text = fragmentSubtitle(l10nEn, const ObfuscationSettings());

      expect(text, startsWith('Off'));
      expect(text, contains('TCP'));
    });

    test('on: shows the values xray gets', () {
      final text = fragmentSubtitle(
        l10nEn,
        const ObfuscationSettings(
          fragmentEnabled: true,
          fragment: FragmentParams(packets: '1-3', length: '50-90', delay: '5-9'),
        ),
      );

      expect(text, equals('1-3 · pieces of 50-90 bytes · pause 5-9 ms'));
    });

    test('follows the language', () {
      const on = ObfuscationSettings(fragmentEnabled: true);

      expect(
        fragmentSubtitle(l10nRu, on),
        isNot(equals(fragmentSubtitle(l10nEn, on))),
      );
      expect(fragmentSubtitle(l10nRu, on), contains('байт'));
    });
  });

  group('noiseSubtitle', () {
    test('off: says it is off and what it would do', () {
      final text = noiseSubtitle(l10nEn, const ObfuscationSettings());

      expect(text, startsWith('Off'));
      expect(text, contains('UDP'));
    });

    test('on: shows the values xray gets', () {
      final text = noiseSubtitle(
        l10nEn,
        const ObfuscationSettings(
          noiseEnabled: true,
          noise: NoiseParams(size: '33-33', delay: '1-2'),
        ),
      );

      expect(text, equals('33-33 bytes of junk · pause 1-2 ms'));
    });
  });

  group('rangeErrorText', () {
    String text(RangeInputError error) =>
        rangeErrorText(l10nEn, error, min: 1, max: 1500);

    test('says what to do for each kind of mistake', () {
      expect(text(RangeInputError.empty), equals('Fill in this field'));
      expect(
        text(RangeInputError.malformed),
        equals('Write a number or a range like 100-200'),
      );
      expect(
        text(RangeInputError.reversed),
        equals('The first number is bigger than the second'),
      );
    });

    test('names the bound that was broken', () {
      expect(text(RangeInputError.tooSmall), equals('At least 1'));
      expect(text(RangeInputError.tooLarge), equals('At most 1500'));
    });

    test('is written in Russian too', () {
      expect(
        rangeErrorText(l10nRu, RangeInputError.tooLarge, min: 1, max: 1500),
        equals('Не больше 1500'),
      );
    });
  });

  group('fragmentPacketsErrorText', () {
    test('a malformed value says what the field takes', () {
      expect(
        fragmentPacketsErrorText(l10nEn, RangeInputError.malformed),
        equals('Write tlshello or a range like 1-3'),
      );
    });

    test('any other mistake reads as for a plain range', () {
      expect(
        fragmentPacketsErrorText(l10nEn, RangeInputError.tooSmall),
        equals('At least 1'),
      );
      expect(
        fragmentPacketsErrorText(l10nEn, RangeInputError.tooLarge),
        equals('At most 1000'),
      );
    });
  });
}
