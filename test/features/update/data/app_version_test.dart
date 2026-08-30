import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream/features/update/data/app_version.dart';

void main() {
  group('isNewerVersion', () {
    test('true when the major.minor.patch core is higher', () {
      expect(
        isNewerVersion(
          current: '1.0.0',
          currentBuild: 21,
          remote: '1.1.0',
          remoteBuild: 1,
        ),
        isTrue,
      );
    });

    test('true when the core is equal but the build number is higher', () {
      expect(
        isNewerVersion(
          current: '1.1.0',
          currentBuild: 1,
          remote: '1.1.0',
          remoteBuild: 2,
        ),
        isTrue,
      );
    });

    test('false when the core is equal and the build number is equal', () {
      expect(
        isNewerVersion(
          current: '1.1.0',
          currentBuild: 2,
          remote: '1.1.0',
          remoteBuild: 2,
        ),
        isFalse,
      );
    });

    test('false when the core and the build number are both lower', () {
      expect(
        isNewerVersion(
          current: '1.1.0',
          currentBuild: 2,
          remote: '1.0.0',
          remoteBuild: 21,
        ),
        isFalse,
      );
    });

    test('false when the core is equal but the build number is lower', () {
      expect(
        isNewerVersion(
          current: '1.1.0',
          currentBuild: 5,
          remote: '1.1.0',
          remoteBuild: 2,
        ),
        isFalse,
      );
    });
  });

  group('parseAppVersion', () {
    test('splits core and build number', () {
      final parsed = parseAppVersion('1.2.3+42');
      expect(parsed.core, equals([1, 2, 3]));
      expect(parsed.build, equals(42));
    });

    test('defaults build to 0 when absent', () {
      final parsed = parseAppVersion('1.2.3');
      expect(parsed.core, equals([1, 2, 3]));
      expect(parsed.build, equals(0));
    });
  });
}
