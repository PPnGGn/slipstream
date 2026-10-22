import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream/features/subscriptions/data/subscription_parser/xray_config_meta.dart';

void main() {
  group('tagLabels', () {
    test('protocol, transport and security in that order', () {
      const meta = XrayServerMeta(
        protocol: 'vless',
        network: 'tcp',
        security: 'reality',
      );
      expect(meta.tagLabels, ['VLESS', 'TCP', 'REALITY']);
    });

    test('hysteria is shown as HYSTERIA2', () {
      const meta = XrayServerMeta(protocol: 'hysteria');
      expect(meta.tagLabels, ['HYSTERIA2']);
    });

    test('a missing transport or security is skipped', () {
      const meta = XrayServerMeta(protocol: 'shadowsocks', network: 'tcp');
      expect(meta.tagLabels, ['SHADOWSOCKS', 'TCP']);
    });

    test('security "none" is noise and is skipped', () {
      const meta = XrayServerMeta(
        protocol: 'vmess',
        network: 'ws',
        security: 'none',
      );
      expect(meta.tagLabels, ['VMESS', 'WS']);
    });

    test('an unreadable config still has a protocol tag', () {
      expect(const XrayServerMeta().tagLabels, ['PROXY']);
    });
  });
}
