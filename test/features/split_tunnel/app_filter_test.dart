import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream/features/split_tunnel/data/app_filter.dart';
import 'package:slipstream/features/split_tunnel/data/split_tunnel_settings.dart';

import 'fakes.dart';

void main() {
  final apps = [
    app('com.chrome', label: 'Chrome'),
    app('com.bank', label: 'Banking'),
    app('com.webview', label: 'WebView', isSystem: true),
  ];

  List<String> packages(Iterable<dynamic> list) =>
      list.map((a) => a.packageName as String).toList();

  group('system apps', () {
    test('hidden by default', () {
      final shown = visibleApps(apps, const SplitTunnelSettings(), '');
      expect(packages(shown), ['com.chrome', 'com.bank']);
    });

    test('shown when includeSystem is on', () {
      final shown = visibleApps(
        apps,
        const SplitTunnelSettings(includeSystem: true),
        '',
      );
      expect(packages(shown), ['com.chrome', 'com.bank', 'com.webview']);
    });

    test('a picked system app stays visible while the switch is off', () {
      final shown = visibleApps(
        apps,
        const SplitTunnelSettings(packages: {'com.webview'}),
        '',
      );
      expect(packages(shown), contains('com.webview'));
    });
  });

  group('search', () {
    const settings = SplitTunnelSettings(includeSystem: true);

    test('an empty or blank query keeps everything', () {
      expect(visibleApps(apps, settings, '  '), hasLength(3));
    });

    test('matches the label, ignoring case', () {
      expect(packages(visibleApps(apps, settings, 'BANK')), ['com.bank']);
    });

    test('matches the package name', () {
      expect(packages(visibleApps(apps, settings, 'com.web')), [
        'com.webview',
      ]);
    });

    test('nothing matches', () {
      expect(visibleApps(apps, settings, 'zzz'), isEmpty);
    });
  });

  group('selectedFirst', () {
    List<String> order(Iterable<dynamic> list) =>
        list.map((a) => a.packageName as String).toList();

    test('moves the pinned apps to the top, keeping the order in each part', () {
      final sorted = selectedFirst(apps, {'com.webview', 'com.bank'});
      expect(order(sorted), ['com.bank', 'com.webview', 'com.chrome']);
    });

    test('nothing pinned keeps the incoming order', () {
      expect(order(selectedFirst(apps, const {})), order(apps));
    });

    test('a pinned package missing from the list changes nothing', () {
      expect(order(selectedFirst(apps, {'gone'})), order(apps));
    });
  });

  test('keeps the incoming order', () {
    final shown = visibleApps(
      apps,
      const SplitTunnelSettings(includeSystem: true),
      '',
    );
    expect(packages(shown), packages(apps));
  });
}
