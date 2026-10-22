import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream/features/qr/data/qr_share_service.dart';

void main() {
  group('safeFileName', () {
    test('turns spaces into underscores', () {
      expect(safeFileName('Nebula Premium'), 'Nebula_Premium');
    });

    test('removes characters file systems reject', () {
      expect(safeFileName('a/b\\c:d*e?f"g<h>i|j'), 'abcdefghij');
    });

    test('removes control characters', () {
      expect(safeFileName('a\u0000b'), 'ab');
    });

    test('keeps non-latin letters', () {
      expect(safeFileName('Мой VPN'), 'Мой_VPN');
    });

    test('trims and collapses whitespace', () {
      expect(safeFileName('  a \t\n b  '), 'a_b');
    });

    test('strips leading and trailing dots', () {
      expect(safeFileName('..name..'), 'name');
    });

    test('falls back to "subscription" when nothing is left', () {
      expect(safeFileName(''), 'subscription');
      expect(safeFileName('   '), 'subscription');
      expect(safeFileName('///'), 'subscription');
      expect(safeFileName('..'), 'subscription');
    });

    test('caps the length at 50 characters', () {
      expect(safeFileName('x' * 80), 'x' * 50);
    });

    test('does not cut an emoji in half', () {
      final name = safeFileName('😀' * 60);

      expect(name.runes.length, 50);
      expect(name, '😀' * 50);
    });
  });

  group('buildShareText', () {
    test('puts the link first, then the signature and the release page', () {
      expect(
        buildShareText('https://x/sub?token=1'),
        'https://x/sub?token=1\n'
        '\n'
        'Sent with the Slipstream VPN client\n'
        'https://github.com/PPnGGn/slipstream/releases/latest',
      );
    });

    test('keeps the link untouched', () {
      const url = 'vless://id@host:443?type=tcp&sni=a.b#Мой%20VPN';

      expect(buildShareText(url), startsWith('$url\n'));
    });
  });

  group('QrShareService.shareQr', () {
    late Directory temp;
    late List<({String path, String text})> sent;

    // Runs before EVERY test below: a fresh temp folder and an empty list of
    // shared files, so the tests cannot affect each other.
    setUp(() {
      temp = Directory.systemTemp.createTempSync('qr_share_service_test');
      sent = [];
    });

    tearDown(() => temp.deleteSync(recursive: true));

    QrShareService service({
      Future<Uint8List> Function(String data)? render,
      Future<void> Function(String path, String text)? send,
    }) {
      return QrShareService.custom(
        render: render ?? (data) async => utf8.encode('png:$data'),
        tempDir: () async => temp,
        send: send ?? (path, text) async => sent.add((path: path, text: text)),
      );
    }

    Directory shareDir() => Directory('${temp.path}/qr_share');

    test(
      'writes the rendered image to a png named after the subscription',
      () async {
        await service().shareQr(data: 'https://x/sub', name: 'Nebula Premium');

        final file = File(sent.single.path);
        expect(file.parent.path, shareDir().path);
        expect(file.uri.pathSegments.last, 'Nebula_Premium.png');
        expect(utf8.decode(file.readAsBytesSync()), 'png:https://x/sub');
      },
    );

    test('sends the share text along with the image', () async {
      await service().shareQr(data: 'https://x/sub', name: 'n');

      expect(sent.single.text, buildShareText('https://x/sub'));
    });

    test('shares the file only after it is written', () async {
      var existedWhenSent = false;

      await service(
        send: (path, _) async => existedWhenSent = File(path).existsSync(),
      ).shareQr(data: 'd', name: 'n');

      expect(existedWhenSent, isTrue);
    });

    test('leaves only the latest image in the share folder', () async {
      await service().shareQr(data: 'a', name: 'First');
      await service().shareQr(data: 'b', name: 'Second');

      final names = shareDir().listSync().map((e) => e.uri.pathSegments.last);
      expect(names, ['Second.png']);
    });

    test('sends nothing when rendering fails', () async {
      final failing = service(render: (_) async => throw StateError('boom'));

      await expectLater(
        failing.shareQr(data: 'd', name: 'n'),
        throwsStateError,
      );
      expect(sent, isEmpty);
    });

    test('passes sending errors on to the caller', () async {
      final failing = service(send: (_, _) async => throw StateError('boom'));

      await expectLater(
        failing.shareQr(data: 'd', name: 'n'),
        throwsStateError,
      );
    });
  });
}
