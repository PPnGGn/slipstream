import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream/features/client_identity/data/client_identity.dart';

void main() {
  group('sanitizeHeaderValue', () {
    test('keeps a plain printable ASCII value untouched', () {
      expect(sanitizeHeaderValue('Pixel 8'), equals('Pixel 8'));
    });

    test('removes CR and LF so a header cannot be split', () {
      final result = sanitizeHeaderValue('Pixel 8\r\nX-Evil: 1');

      expect(result, isNot(contains('\r')));
      expect(result, isNot(contains('\n')));
      expect(result, equals('Pixel 8X-Evil: 1'));
    });

    test('removes other control characters and DEL', () {
      expect(sanitizeHeaderValue('a\tb\u0000c\u007Fd'), equals('abcd'));
    });

    test('removes non-ASCII characters', () {
      expect(sanitizeHeaderValue('Редми 12'), equals('12'));
    });

    test('trims surrounding spaces', () {
      expect(sanitizeHeaderValue('  Pixel 8  '), equals('Pixel 8'));
    });

    test('returns an empty string when nothing printable is left', () {
      expect(sanitizeHeaderValue('Хэпп\r\n'), isEmpty);
    });

    test('cuts the value to 256 characters', () {
      expect(sanitizeHeaderValue('a' * 300), equals('a' * 256));
    });

    test('does not leave a trailing space after cutting', () {
      final result = sanitizeHeaderValue('${'a' * 255} bbb');

      expect(result, equals('a' * 255));
    });
  });

  group('ClientIdentity.toHeaders', () {
    test('returns all five headers for a full identity', () {
      const identity = ClientIdentity(
        userAgent: 'Happ/4.7.1',
        hwid: '3f2a9c1e-7b4d-4e21-9a0f-5c6d7e8f9a0b',
        deviceOs: 'Android',
        osVersion: '14',
        deviceModel: 'Pixel 8',
      );

      expect(
        identity.toHeaders(),
        equals({
          'User-Agent': 'Happ/4.7.1',
          'x-hwid': '3f2a9c1e-7b4d-4e21-9a0f-5c6d7e8f9a0b',
          'x-device-os': 'Android',
          'x-ver-os': '14',
          'x-device-model': 'Pixel 8',
        }),
      );
    });

    test('omits headers whose value is null or empty', () {
      const identity = ClientIdentity(
        userAgent: 'Happ/4.7.1',
        hwid: '3f2a9c1e-7b4d-4e21-9a0f-5c6d7e8f9a0b',
        deviceOs: 'Android',
        osVersion: null,
        deviceModel: '',
      );

      final headers = identity.toHeaders();

      expect(headers.containsKey('x-ver-os'), isFalse);
      expect(headers.containsKey('x-device-model'), isFalse);
      expect(headers, hasLength(3));
    });

    test('omits a header when nothing printable is left after cleaning', () {
      const identity = ClientIdentity(
        userAgent: 'Happ/4.7.1',
        hwid: '3f2a9c1e-7b4d-4e21-9a0f-5c6d7e8f9a0b',
        deviceModel: 'Редми',
      );

      expect(identity.toHeaders().containsKey('x-device-model'), isFalse);
    });

    test('strips CR and LF from the device model', () {
      const identity = ClientIdentity(
        userAgent: 'Happ/4.7.1',
        hwid: '3f2a9c1e-7b4d-4e21-9a0f-5c6d7e8f9a0b',
        deviceModel: 'Pixel 8\r\nX-Evil: 1',
      );

      final model = identity.toHeaders()['x-device-model']!;

      expect(model, isNot(contains('\r')));
      expect(model, isNot(contains('\n')));
    });
  });
}
