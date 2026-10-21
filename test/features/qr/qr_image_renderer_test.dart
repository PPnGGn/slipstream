import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:slipstream/features/qr/data/qr_image_renderer.dart';

const _data = 'https://nebula.stream/sub/9f2c41d8a7?token=xK3m';

class _Decoded {
  _Decoded(this.width, this.height, this.rgba);

  final int width;
  final int height;
  final ByteData rgba;

  bool isDark(int x, int y) => rgba.getUint8((y * width + x) * 4) < 64;

  bool isOpaqueWhite(int x, int y) {
    final i = (y * width + x) * 4;
    return rgba.getUint8(i) == 255 &&
        rgba.getUint8(i + 1) == 255 &&
        rgba.getUint8(i + 2) == 255 &&
        rgba.getUint8(i + 3) == 255;
  }
}

Future<_Decoded> _decode(Uint8List png) async {
  final image = await decodeImageFromList(png);
  final rgba = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  return _Decoded(image.width, image.height, rgba);
}

void main() {
  const size = 512;
  final modules = QrValidator.validate(data: _data).qrCode!.moduleCount;
  // 4 empty modules on each side of the code.
  final grid = modules + 8;
  final module = size ~/ grid;

  group('renderQrPng', () {
    testWidgets('produces a PNG', (tester) async {
      final bytes = await tester.runAsync(() => renderQrPng(_data, size: size));

      expect(bytes!.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10]);
    });

    testWidgets('is a square that fits whole modules into the size', (
      tester,
    ) async {
      final image = await tester.runAsync(() async {
        return _decode(await renderQrPng(_data, size: size));
      });

      expect(image!.width, image.height);
      expect(image.width, module * grid);
      expect(image.width, lessThanOrEqualTo(size));
      expect(image.width, greaterThan(size - grid));
    });

    testWidgets('keeps an opaque white quiet zone on every side', (
      tester,
    ) async {
      final image = (await tester.runAsync(() async {
        return _decode(await renderQrPng(_data, size: size));
      }))!;
      final last = image.width - 1;

      expect(image.isOpaqueWhite(0, 0), isTrue);
      expect(image.isOpaqueWhite(last, 0), isTrue);
      expect(image.isOpaqueWhite(0, last), isTrue);
      expect(image.isOpaqueWhite(last, last), isTrue);
      // The row and column right before the first module.
      expect(image.isOpaqueWhite(module * 4 - 1, module * 4 - 1), isTrue);
    });

    testWidgets('draws the top-left finder pattern in black on white', (
      tester,
    ) async {
      final image = (await tester.runAsync(() async {
        return _decode(await renderQrPng(_data, size: size));
      }))!;
      // Pixel in the middle of the module `n` modules inside the code.
      int at(int n) => module * (4 + n) + module ~/ 2;

      expect(image.isDark(at(0), at(0)), isTrue, reason: 'outer ring');
      expect(image.isDark(at(1), at(1)), isFalse, reason: 'inner white ring');
      expect(image.isDark(at(3), at(3)), isTrue, reason: 'center');
    });

    testWidgets('throws when the data cannot fit into a QR code', (
      tester,
    ) async {
      // runAsync would swallow the error, so the check runs inside it.
      await tester.runAsync(() async {
        await expectLater(
          renderQrPng('x' * 10000, size: size),
          throwsArgumentError,
        );
      });
    });
  });
}
