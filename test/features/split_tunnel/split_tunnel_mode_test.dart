import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream/features/split_tunnel/data/split_tunnel_mode.dart';

void main() {
  test('stored names round-trip', () {
    for (final mode in SplitTunnelMode.values) {
      expect(SplitTunnelMode.fromName(mode.name), mode);
    }
  });

  test('nothing stored falls back to bypass', () {
    expect(SplitTunnelMode.fromName(null), SplitTunnelMode.bypass);
  });

  test('an unknown stored value falls back to bypass', () {
    expect(SplitTunnelMode.fromName('wat'), SplitTunnelMode.bypass);
  });
}
