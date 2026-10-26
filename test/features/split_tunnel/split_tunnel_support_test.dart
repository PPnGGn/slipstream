import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream/features/split_tunnel/data/split_tunnel_support.dart';

void main() {
  test('supported only on Android', () {
    expect(isSplitTunnelSupported(TargetPlatform.android), isTrue);
    expect(isSplitTunnelSupported(TargetPlatform.iOS), isFalse);
    expect(isSplitTunnelSupported(TargetPlatform.windows), isFalse);
    expect(isSplitTunnelSupported(TargetPlatform.macOS), isFalse);
  });
}
