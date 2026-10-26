import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream/features/split_tunnel/data/split_tunnel_mode.dart';
import 'package:slipstream/features/split_tunnel/data/split_tunnel_settings.dart';

void main() {
  test('defaults: off, bypass, nothing picked, system apps hidden', () {
    const settings = SplitTunnelSettings();
    expect(settings.enabled, isFalse);
    expect(settings.mode, SplitTunnelMode.bypass);
    expect(settings.packages, isEmpty);
    expect(settings.includeSystem, isFalse);
  });

  group('isActive', () {
    test('false when the switch is off, even with apps picked', () {
      const settings = SplitTunnelSettings(packages: {'a.b'});
      expect(settings.isActive, isFalse);
    });

    test('false when the list is empty, in either mode', () {
      for (final mode in SplitTunnelMode.values) {
        final settings = SplitTunnelSettings(enabled: true, mode: mode);
        expect(settings.isActive, isFalse);
      }
    });

    test('true when on and at least one app is picked', () {
      const settings = SplitTunnelSettings(enabled: true, packages: {'a.b'});
      expect(settings.isActive, isTrue);
    });
  });

  test('copyWith changes only the given fields', () {
    const settings = SplitTunnelSettings(
      enabled: true,
      mode: SplitTunnelMode.proxy,
      packages: {'a.b'},
    );
    final changed = settings.copyWith(includeSystem: true);
    expect(changed.enabled, isTrue);
    expect(changed.mode, SplitTunnelMode.proxy);
    expect(changed.packages, {'a.b'});
    expect(changed.includeSystem, isTrue);
  });

  test('equal when all fields are equal, regardless of set order', () {
    const a = SplitTunnelSettings(packages: {'a', 'b'});
    const b = SplitTunnelSettings(packages: {'b', 'a'});
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a == a.copyWith(enabled: true), isFalse);
  });
}
