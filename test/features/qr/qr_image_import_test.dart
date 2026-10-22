import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream/features/qr/data/qr_image_import.dart';

void main() {
  group('QrImageImporter.import', () {
    late List<String> readPaths;

    // Runs before EVERY test below, so each test starts with no reads.
    setUp(() {
      readPaths = [];
    });

    QrImageImporter importer({
      String? picked = '/tmp/screenshot.png',
      List<String?> values = const [],
      Object? readError,
    }) {
      return QrImageImporter.custom(
        pickImagePath: () async => picked,
        readQrValues: (path) async {
          readPaths.add(path);
          if (readError != null) throw readError;
          return values;
        },
      );
    }

    test(
      'is cancelled when no image was picked, without reading anything',
      () async {
        final result = await importer(picked: null).import();

        expect(result, isA<QrImportCancelled>());
        expect(readPaths, isEmpty);
      },
    );

    test('reads the picked image', () async {
      await importer(picked: '/tmp/a.png').import();

      expect(readPaths, ['/tmp/a.png']);
    });

    test('finds the QR text, trimmed', () async {
      final result = await importer(values: ['  vless://x \n']).import();

      expect(
        result,
        isA<QrImportFound>().having((r) => r.text, 'text', 'vless://x'),
      );
    });

    test('takes the first non-blank value out of several', () async {
      final result = await importer(
        values: [null, '  ', 'https://panel.example/sub', 'second'],
      ).import();

      expect(
        result,
        isA<QrImportFound>().having(
          (r) => r.text,
          'text',
          'https://panel.example/sub',
        ),
      );
    });

    test('is not found when the image has no QR code', () async {
      expect(await importer().import(), isA<QrImportNotFound>());
    });

    test('is not found when every value is blank', () async {
      final result = await importer(values: [null, '', '   ']).import();

      expect(result, isA<QrImportNotFound>());
    });

    test('is not found when reading the image fails', () async {
      final result = await importer(readError: Exception('bad image')).import();

      expect(result, isA<QrImportNotFound>());
    });
  });
}
