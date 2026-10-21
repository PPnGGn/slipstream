import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream/features/qr/data/qr_scan.dart';

void main() {
  group('QrScanSession.accept', () {
    late QrScanSession session;

    // Runs before EVERY test below, so each test gets a fresh session
    // and the tests cannot affect each other.
    setUp(() {
      session = QrScanSession();
    });

    test('returns null when nothing was detected', () {
      expect(session.accept([]), isNull);
    });

    test('ignores null and blank values', () {
      expect(session.accept([null, '', '   ']), isNull);
    });

    test('returns the value trimmed', () {
      expect(session.accept(['  vless://x \n']), 'vless://x');
    });

    test('takes the first non-empty value out of several', () {
      expect(session.accept([null, '  ', 'first', 'second']), 'first');
    });

    test('blank values do not finish the scan', () {
      session.accept([null, '  ']);

      expect(session.accept(['https://panel.example/sub']), isNotNull);
    });

    test('returns null after a successful scan', () {
      session.accept(['first']);

      expect(session.accept(['second']), isNull);
    });
  });

  group('isQrScanSupported', () {
    test('is true on Android and iOS', () {
      expect(isQrScanSupported(TargetPlatform.android), isTrue);
      expect(isQrScanSupported(TargetPlatform.iOS), isTrue);
    });

    test('is false on every other platform', () {
      final others = TargetPlatform.values.where(
        (p) => p != TargetPlatform.android && p != TargetPlatform.iOS,
      );

      for (final platform in others) {
        expect(isQrScanSupported(platform), isFalse, reason: '$platform');
      }
    });
  });
}
