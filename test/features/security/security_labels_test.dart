import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream/features/security/data/security_support.dart';
import 'package:slipstream/features/security/ui/security_labels.dart';

void main() {
  group('isSecuritySupported', () {
    test('is Android only', () {
      expect(isSecuritySupported(TargetPlatform.android), isTrue);
      expect(isSecuritySupported(TargetPlatform.iOS), isFalse);
      expect(isSecuritySupported(TargetPlatform.windows), isFalse);
      expect(isSecuritySupported(TargetPlatform.macOS), isFalse);
    });
  });

  group('killSwitchSubtitle', () {
    test('on: says traffic is blocked when the tunnel is lost', () {
      expect(
        killSwitchSubtitle(enabled: true),
        'Blocks traffic if the tunnel is lost',
      );
    });

    test('off: says a lost tunnel just closes the VPN', () {
      expect(
        killSwitchSubtitle(enabled: false),
        'Off · a lost tunnel just closes the VPN',
      );
    });
  });

  group('ipv6Subtitle', () {
    test('on: says IPv6 goes through the tunnel', () {
      expect(ipv6Subtitle(enabled: true), 'IPv6 goes through the tunnel');
    });

    test('off: says what apps do instead', () {
      expect(ipv6Subtitle(enabled: false), 'Off · apps use IPv4 only');
    });
  });
}
