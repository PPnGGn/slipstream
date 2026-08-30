import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream/core/utils/formatters.dart';

void main() {
  group('countryCodeFromFlag', () {
    test(
      'extracts country code from a flag emoji at the start of the string',
      () {
        // 🇳🇱 = regional indicators N (\u{1F1F3}) + L (\u{1F1F1})
        final remarks = '\u{1F1F3}\u{1F1F1} Netherlands #1';

        expect(countryCodeFromFlag(remarks), equals('NL'));
      },
    );

    test('extracts country code from a flag emoji', () {
      expect(countryCodeFromFlag('🇳🇱 Netherlands #1'), equals('NL'));
    });

    test('returns null when the string has no flag', () {
      expect(countryCodeFromFlag('Netherlands #1'), isNull);
    });

    test('returns null for an empty string', () {
      expect(countryCodeFromFlag(''), isNull);
    });

    test('extracts AA at the lower bound of the regional indicator range', () {
      expect(
        countryCodeFromFlag('\u{1F1E6}\u{1F1E6} some server AA'),
        equals('AA'),
      );
    });

    test('extracts ZZ at the upper bound of the regional indicator range', () {
      expect(
        countryCodeFromFlag('\u{1F1FF}\u{1F1FF} some server ZZ'),
        equals('ZZ'),
      );
    });

    test('returns null when only a single flag indicator is present', () {
      expect(countryCodeFromFlag('\u{1F1E6} some server'), isNull);
    });

    test('returns null for a non-flag emoji at the start', () {
      expect(countryCodeFromFlag('😀 some server #22'), isNull);
    });

    test('returns null when the flag emoji is not at the start', () {
      expect(countryCodeFromFlag('Netherlands #1 🇳🇱'), isNull);
    });

    test('round-trips with countryFlag', () {
      expect(
        countryCodeFromFlag('${countryFlag('NL')} Amsterdam'),
        equals('NL'),
      );
    });
  });

  group('startsWithFlagEmoji', () {
    test('is true for a leading flag', () {
      expect(startsWithFlagEmoji('🇳🇱 Netherlands'), isTrue);
    });

    test('is false for plain text', () {
      expect(startsWithFlagEmoji('Netherlands'), isFalse);
    });
  });

  group('countryFlag', () {
    test('turns a 2-letter code into a flag', () {
      expect(countryFlag('NL'), equals('🇳🇱'));
    });

    test('is case insensitive', () {
      expect(countryFlag('nl'), equals('🇳🇱'));
    });

    test('falls back to a white flag for a malformed code', () {
      expect(countryFlag('N'), equals('🏳️'));
    });
  });
}
