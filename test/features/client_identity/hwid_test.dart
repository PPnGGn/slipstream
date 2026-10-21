import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream/features/client_identity/data/hwid.dart';

void main() {
  group('isValidHwid', () {
    test('rejects 9 characters', () {
      expect(isValidHwid('a' * 9), isFalse);
    });

    test('accepts 10 characters', () {
      expect(isValidHwid('a' * 10), isTrue);
    });

    test('accepts 64 characters', () {
      expect(isValidHwid('a' * 64), isTrue);
    });

    test('rejects 65 characters', () {
      expect(isValidHwid('a' * 65), isFalse);
    });

    test('rejects an empty string', () {
      expect(isValidHwid(''), isFalse);
    });

    test('accepts latin letters, digits, dash and equals sign', () {
      expect(isValidHwid('Abc-123=xyz'), isTrue);
    });

    test('rejects an underscore', () {
      expect(isValidHwid('abcde_fghij'), isFalse);
    });

    test('rejects a space', () {
      expect(isValidHwid('abcde fghij'), isFalse);
    });

    test('rejects cyrillic letters', () {
      expect(isValidHwid('абвгдежзийк'), isFalse);
    });

    test('rejects a valid core surrounded by garbage (anchors work)', () {
      expect(isValidHwid('!!!abcdefghij!!!'), isFalse);
    });

    test('rejects a trailing newline', () {
      expect(isValidHwid('abcdefghij\n'), isFalse);
    });
  });

  group('hwidFromDeviceId', () {
    final uuidShape = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    );

    test('returns the same value for the same input', () {
      expect(hwidFromDeviceId('abc'), equals(hwidFromDeviceId('abc')));
    });

    test('returns different values for different inputs', () {
      expect(hwidFromDeviceId('abc'), isNot(equals(hwidFromDeviceId('abd'))));
    });

    test('has the 8-4-4-4-12 lowercase hex shape', () {
      expect(hwidFromDeviceId('abc'), matches(uuidShape));
    });

    test('passes the panel validation', () {
      expect(isValidHwid(hwidFromDeviceId('abc')), isTrue);
    });

    test('is pinned to the salt and algorithm', () {
      // Computed outside Dart: printf 'slipstream_hwid_abc' | sha256sum.
      // If this fails, every user would get a new HWID, so never change the salt.
      expect(
        hwidFromDeviceId('abc'),
        equals('9055be34-bfef-3420-9430-8133456a3f67'),
      );
    });
  });

  group('randomHwid', () {
    test('passes the panel validation', () {
      expect(isValidHwid(randomHwid()), isTrue);
    });

    test('returns different values on each call', () {
      expect(randomHwid(), isNot(equals(randomHwid())));
    });
  });
}
