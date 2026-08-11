import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream/features/subscriptions/data/subscription_parser/country_code_extractor.dart';

void main() {
  final extractor = CountryCodeExtractor();

  group('CountryCodeExtractor', () {
    test(
      'extracts country code from a flag emoji at the start of the string',
      () {
        // 🇳🇱 = regional indicators N (\u{1F1F3}) + L (\u{1F1F1})
        final remarks = '\u{1F1F3}\u{1F1F1} Netherlands #1';

        final countryCode = extractor.extract(remarks);

        expect(countryCode, equals('NL'));
      },
    );

    test('extracts country code from a flag emoji', () {
      final remarks = '🇳🇱 Netherlands #1';

      final countryCode = extractor.extract(remarks);

      expect(countryCode, equals('NL'));
    });

    test('returns XX when the string has no flag', () {
      final remarks = 'Netherlands #1';

      final countryCode = extractor.extract(remarks);

      expect(countryCode, equals('XX'));
    });

    test('returns XX for an empty string', () {
      final countryCode = extractor.extract('');

      expect(countryCode, equals('XX'));
    });

    test('extracts AA at the lower bound of the regional indicator range', () {
      final remarks = '\u{1F1E6}\u{1F1E6} some server AA';
      final countryCode = extractor.extract(remarks);
      expect(countryCode, equals('AA'));
    });

    test('extracts ZZ at the upper bound of the regional indicator range', () {
      final remarks = '\u{1F1FF}\u{1F1FF} some server ZZ';
      final countryCode = extractor.extract(remarks);
      expect(countryCode, equals('ZZ'));
    });

    test('returns XX when only a single flag indicator is present', () {
      final remarks = '\u{1F1E6} some server';

      final countryCode = extractor.extract(remarks);

      expect(countryCode, equals('XX'));
    });

    test('returns XX for a non-flag emoji at the start', () {
      final remarks = '😀 some server #22';

      final countryCode = extractor.extract(remarks);

      expect(countryCode, equals('XX'));
    });

    test('returns XX when the flag emoji is not at the start', () {
      final remarks = 'Netherlands #1 🇳🇱';

      final countryCode = extractor.extract(remarks);

      expect(countryCode, equals('XX'));
    });
  });
}
