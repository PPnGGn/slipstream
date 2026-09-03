import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream/features/update/data/update_cache.dart';

void main() {
  late Directory tempDir;
  late Directory updatesDir;
  late Directory subscriptionsDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('update_cache_test');
    updatesDir = Directory('${tempDir.path}${Platform.pathSeparator}updates')
      ..createSync();
    subscriptionsDir = Directory(
      '${tempDir.path}${Platform.pathSeparator}subscriptions',
    )..createSync();
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('apkFileName', () {
    test('formats version and build number', () {
      expect(apkFileName('1.2.0', 23), equals('slipstream-1.2.0+23.apk'));
    });
  });

  group('apkPath', () {
    test('joins updates dir with versioned file name', () {
      expect(
        apkPath(updatesDir, '1.2.0', 23),
        equals(
          '${updatesDir.path}${Platform.pathSeparator}slipstream-1.2.0+23.apk',
        ),
      );
    });
  });

  group('cachedApkStatus', () {
    test('missing when the file does not exist', () {
      final file = File(apkPath(updatesDir, '1.0.0', 1));
      expect(cachedApkStatus(file, 10), equals(CachedApkStatus.missing));
    });

    test('complete when length matches sizeBytes', () {
      final file = File(apkPath(updatesDir, '1.0.0', 1))
        ..writeAsBytesSync(List.filled(10, 1));
      expect(cachedApkStatus(file, 10), equals(CachedApkStatus.complete));
    });

    test('partial when length is smaller than sizeBytes', () {
      final file = File(apkPath(updatesDir, '1.0.0', 1))
        ..writeAsBytesSync(List.filled(4, 1));
      expect(cachedApkStatus(file, 10), equals(CachedApkStatus.partial));
    });

    test('oversized when length is larger than sizeBytes', () {
      final file = File(apkPath(updatesDir, '1.0.0', 1))
        ..writeAsBytesSync(List.filled(12, 1));
      expect(cachedApkStatus(file, 10), equals(CachedApkStatus.oversized));
    });
  });

  group('purgeOtherApks', () {
    test('does nothing when the directory does not exist', () async {
      final missing = Directory(
        '${tempDir.path}${Platform.pathSeparator}no-such-dir',
      );
      await purgeOtherApks(missing);
    });

    test('deletes other apks and keeps the matching file', () async {
      final keepPath = apkPath(updatesDir, '1.1.0', 2);
      File(keepPath).writeAsBytesSync([1]);
      File(apkPath(updatesDir, '1.0.0', 1)).writeAsBytesSync([1]);
      File(
        '${subscriptionsDir.path}${Platform.pathSeparator}sub.json',
      ).writeAsStringSync('{"ok":true}');

      await purgeOtherApks(updatesDir, keep: keepPath);

      expect(File(keepPath).existsSync(), isTrue);
      expect(File(apkPath(updatesDir, '1.0.0', 1)).existsSync(), isFalse);
      expect(
        File(
          '${subscriptionsDir.path}${Platform.pathSeparator}sub.json',
        ).existsSync(),
        isTrue,
      );
    });

    test('deletes all apks when keep is omitted', () async {
      File(apkPath(updatesDir, '1.0.0', 1)).writeAsBytesSync([1]);
      File(apkPath(updatesDir, '1.1.0', 2)).writeAsBytesSync([1]);
      File(
        '${subscriptionsDir.path}${Platform.pathSeparator}sub.json',
      ).writeAsStringSync('{"ok":true}');

      await purgeOtherApks(updatesDir);

      expect(updatesDir.listSync().whereType<File>(), isEmpty);
      expect(
        File(
          '${subscriptionsDir.path}${Platform.pathSeparator}sub.json',
        ).existsSync(),
        isTrue,
      );
    });

    test('does not delete non-apk files in updates dir', () async {
      final sidecar = File(
        '${updatesDir.path}${Platform.pathSeparator}notes.txt',
      )..writeAsStringSync('keep me');
      File(apkPath(updatesDir, '1.0.0', 1)).writeAsBytesSync([1]);

      await purgeOtherApks(updatesDir);

      expect(sidecar.existsSync(), isTrue);
      expect(File(apkPath(updatesDir, '1.0.0', 1)).existsSync(), isFalse);
    });
  });
}
