import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream/core/models/app_release/app_release.dart';
import 'package:slipstream/core/service/update_service/update_service_cubit.dart';
import 'package:slipstream/features/update/ui/update_dialog_content.dart';

const _release = AppRelease(
  version: '2.1.1',
  buildNumber: 37,
  tagName: 'v2.1.1+37',
  downloadUrl: 'https://example.com/slipstream-android.apk',
  // 18.4 MB, as in the design.
  sizeBytes: 19293798,
  notes: ['Search in split tunneling', 'Fixed reconnect loop'],
);

void main() {
  const installed = '2.1.0 (36)';

  group('a downloaded update', () {
    final content = updateDialogContent(
      const UpdateState.readyToInstall(_release, 'update.apk'),
      installed,
    )!;

    test('is the "ready to install" card', () {
      expect(content.kind, UpdateDialogKind.ready);
      expect(content.eyebrow, 'DOWNLOADED · 18.4 MB');
      expect(content.title, 'Update ready to install');
    });

    test('shows the version it replaces and the new one', () {
      expect(content.fromVersion, '2.1.0 (36)');
      expect(content.toVersion, '2.1.1 (37)');
    });

    test('lists what is new, from the release notes', () {
      expect(content.sectionLabel, "WHAT'S NEW");
      expect(content.items, ['Search in split tunneling', 'Fixed reconnect loop']);
    });

    test('says honestly what happens next', () {
      expect(
        content.hint,
        'System installer opens · reconnect VPN after update',
      );
    });
  });

  test('a release without notes has an empty list, so no block is drawn', () {
    final content = updateDialogContent(
      UpdateState.readyToInstall(_release.copyWith(notes: const []), 'u.apk'),
      installed,
    )!;

    expect(content.items, isEmpty);
  });

  test('without a known installed version only the new one is shown', () {
    final content = updateDialogContent(
      const UpdateState.readyToInstall(_release, 'update.apk'),
      null,
    )!;

    expect(content.fromVersion, isNull);
    expect(content.toVersion, '2.1.1 (37)');
  });

  group('a signature conflict', () {
    final content = updateDialogContent(
      const UpdateState.signatureConflict(_release, 'update.apk'),
      installed,
    )!;

    test('is the "reinstall required" card', () {
      expect(content.kind, UpdateDialogKind.reinstall);
      expect(content.eyebrow, 'SIGNATURE MISMATCH');
      expect(content.title, 'Reinstall required');
    });

    test('lists the three steps instead of release notes', () {
      expect(content.sectionLabel, 'WHAT TO DO');
      expect(content.items, [
        'Save the APK',
        'Uninstall Slipstream',
        'Open the saved APK to install v2.1.1',
      ]);
    });

    test('warns that uninstalling removes the saved subscriptions', () {
      expect(
        content.hint,
        'Uninstalling also removes your saved subscriptions',
      );
    });
  });

  test('every other state has no dialog', () {
    for (final state in [
      const UpdateState.idle(),
      const UpdateState.checking(),
      const UpdateState.upToDate(),
      UpdateState.downloading(_release, receivedBytes: 1),
      const UpdateState.error('x'),
    ]) {
      expect(updateDialogContent(state, installed), isNull, reason: '$state');
    }
  });
}
