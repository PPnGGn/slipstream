import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream/features/security/data/obfuscation_settings.dart';

void main() {
  group('defaults', () {
    test('both options are off for a fresh install', () {
      const settings = ObfuscationSettings();

      expect(settings.fragmentEnabled, isFalse);
      expect(settings.noiseEnabled, isFalse);
    });

    test('fragment cuts the TLS hello into pieces of 100 to 200 bytes', () {
      const fragment = FragmentParams();

      expect(fragment.packets, equals('tlshello'));
      expect(fragment.length, equals('100-200'));
      expect(fragment.delay, equals('10-20'));
    });

    test('noise is 10 to 20 random bytes, then a pause of 10 to 16 ms', () {
      const noise = NoiseParams();

      expect(noise.size, equals('10-20'));
      expect(noise.delay, equals('10-16'));
    });

    test('the defaults pass their own validation', () {
      expect(validateFragment(const FragmentParams()).isValid, isTrue);
      expect(validateNoise(const NoiseParams()).isValid, isTrue);
    });
  });

  group('settings are values', () {
    test('equal settings compare equal, so an unchanged save emits nothing', () {
      expect(const ObfuscationSettings(), equals(const ObfuscationSettings()));
      expect(
        const ObfuscationSettings(fragmentEnabled: true),
        isNot(equals(const ObfuscationSettings())),
      );
    });

    test('copyWith changes only what it is given', () {
      final changed = const ObfuscationSettings().copyWith(noiseEnabled: true);

      expect(changed.noiseEnabled, isTrue);
      expect(changed.fragmentEnabled, isFalse);
      expect(changed.fragment, equals(const FragmentParams()));
    });
  });

  group('parseRange', () {
    test('reads a range', () {
      expect(parseRange('100-200'), equals((from: 100, to: 200)));
    });

    test('reads a single number as a range of one value', () {
      expect(parseRange('150'), equals((from: 150, to: 150)));
    });

    test('ignores spaces around the numbers and the dash', () {
      expect(parseRange(' 100 - 200 '), equals((from: 100, to: 200)));
    });

    test('returns null for anything else', () {
      for (final bad in ['', '  ', 'abc', '1-', '-5', '1-2-3', '1.5', '1,2']) {
        expect(parseRange(bad), isNull, reason: '"$bad"');
      }
    });
  });

  group('validateRange', () {
    RangeInputError? check(String raw) =>
        validateRange(raw, min: 1, max: 1500);

    test('accepts a range and a single number inside the bounds', () {
      expect(check('1-1500'), isNull);
      expect(check('300'), isNull);
    });

    test('an empty field is its own error', () {
      expect(check(''), equals(RangeInputError.empty));
      expect(check('   '), equals(RangeInputError.empty));
    });

    test('text that is not a number or a range is malformed', () {
      expect(check('abc'), equals(RangeInputError.malformed));
      expect(check('1-2-3'), equals(RangeInputError.malformed));
    });

    test('a range written backwards is reversed', () {
      expect(check('200-100'), equals(RangeInputError.reversed));
    });

    test('a value under the minimum is too small', () {
      expect(check('0-10'), equals(RangeInputError.tooSmall));
    });

    test('a value over the maximum is too large', () {
      expect(check('100-1501'), equals(RangeInputError.tooLarge));
    });
  });

  group('validateFragment', () {
    test('packets may be tlshello in any case', () {
      expect(
        validateFragment(const FragmentParams(packets: 'TLSHello')).packets,
        isNull,
      );
    });

    test('packets may be a range of packet numbers from 1', () {
      expect(
        validateFragment(const FragmentParams(packets: '1-3')).packets,
        isNull,
      );
      expect(
        validateFragment(const FragmentParams(packets: '0-3')).packets,
        equals(RangeInputError.tooSmall),
      );
    });

    test('length starts at 1 byte: xray refuses a piece of 0', () {
      expect(
        validateFragment(const FragmentParams(length: '0-10')).length,
        equals(RangeInputError.tooSmall),
      );
    });

    test('a pause may be 0 but not long enough to stall the handshake', () {
      expect(
        validateFragment(const FragmentParams(delay: '0-0')).delay,
        isNull,
      );
      expect(
        validateFragment(const FragmentParams(delay: '0-501')).delay,
        equals(RangeInputError.tooLarge),
      );
    });

    test('reports each field on its own', () {
      final errors = validateFragment(
        const FragmentParams(packets: 'x', length: '', delay: '9-1'),
      );

      expect(errors.isValid, isFalse);
      expect(errors.packets, equals(RangeInputError.malformed));
      expect(errors.length, equals(RangeInputError.empty));
      expect(errors.delay, equals(RangeInputError.reversed));
    });
  });

  group('validateNoise', () {
    test('size is at least 1 byte and fits one UDP datagram', () {
      expect(
        validateNoise(const NoiseParams(size: '0-10')).size,
        equals(RangeInputError.tooSmall),
      );
      expect(
        validateNoise(const NoiseParams(size: '1-1400')).size,
        isNull,
      );
      expect(
        validateNoise(const NoiseParams(size: '1-1401')).size,
        equals(RangeInputError.tooLarge),
      );
    });

    test('a pause may be 0 up to 500 ms', () {
      expect(validateNoise(const NoiseParams(delay: '0')).delay, isNull);
      expect(
        validateNoise(const NoiseParams(delay: '501')).delay,
        equals(RangeInputError.tooLarge),
      );
    });
  });

  group('normalized', () {
    test('writes every range as from-to, so xray reads one form', () {
      final fragment = const FragmentParams(
        packets: ' TLSHello ',
        length: '150',
        delay: ' 10 - 20 ',
      ).normalized();

      expect(fragment.packets, equals('tlshello'));
      expect(fragment.length, equals('150-150'));
      expect(fragment.delay, equals('10-20'));

      final noise = const NoiseParams(size: '12', delay: '1 -2').normalized();
      expect(noise.size, equals('12-12'));
      expect(noise.delay, equals('1-2'));
    });
  });
}
