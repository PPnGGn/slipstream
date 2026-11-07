import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream/features/dns/data/direct_dns.dart';
import 'package:slipstream/features/dns/data/dns_settings.dart';
import 'package:slipstream/features/dns/data/dns_support.dart';
import 'package:slipstream/features/dns/data/remote_dns.dart';

void main() {
  group('RemoteDns', () {
    test('every option carries the address xray gets', () {
      expect(RemoteDns.cloudflare.address, 'https://1.1.1.1/dns-query');
      expect(RemoteDns.google.address, 'https://8.8.8.8/dns-query');
      // Plain UDP 53 to the resolver, reached through the tunnel.
      expect(RemoteDns.xray.address, '1.1.1.1');
    });

    test('fromName finds an option by its stored name', () {
      expect(RemoteDns.fromName('cloudflare'), RemoteDns.cloudflare);
      expect(RemoteDns.fromName('google'), RemoteDns.google);
      expect(RemoteDns.fromName('xray'), RemoteDns.xray);
    });

    test('fromName falls back to google for null and unknown names', () {
      expect(RemoteDns.fromName(null), RemoteDns.google);
      expect(RemoteDns.fromName('quad9'), RemoteDns.google);
    });
  });

  group('DirectDns', () {
    test('every option carries the address xray gets', () {
      expect(DirectDns.yandex.address, 'https://77.88.8.8/dns-query');
      // xray's name for "ask the operating system".
      expect(DirectDns.system.address, 'localhost');
    });

    test('fromName finds an option by its stored name', () {
      expect(DirectDns.fromName('yandex'), DirectDns.yandex);
      expect(DirectDns.fromName('system'), DirectDns.system);
    });

    test('fromName falls back to yandex for null and unknown names', () {
      expect(DirectDns.fromName(null), DirectDns.yandex);
      expect(DirectDns.fromName('isp'), DirectDns.yandex);
    });
  });

  group('DnsSettings', () {
    test('defaults keep today\'s behaviour', () {
      const settings = DnsSettings();
      expect(settings.remote, RemoteDns.google);
      expect(settings.direct, DirectDns.yandex);
      expect(settings.fakeDns, isFalse);
    });

    test('copyWith changes only the named field', () {
      const base = DnsSettings(
        remote: RemoteDns.cloudflare,
        direct: DirectDns.system,
        fakeDns: true,
      );
      expect(
        base.copyWith(remote: RemoteDns.xray),
        const DnsSettings(
          remote: RemoteDns.xray,
          direct: DirectDns.system,
          fakeDns: true,
        ),
      );
      expect(
        base.copyWith(direct: DirectDns.yandex),
        const DnsSettings(
          remote: RemoteDns.cloudflare,
          direct: DirectDns.yandex,
          fakeDns: true,
        ),
      );
      expect(
        base.copyWith(fakeDns: false),
        const DnsSettings(
          remote: RemoteDns.cloudflare,
          direct: DirectDns.system,
        ),
      );
    });

    test('equal values are equal, so a cubit does not re-emit them', () {
      const a = DnsSettings(remote: RemoteDns.xray, fakeDns: true);
      const b = DnsSettings(remote: RemoteDns.xray, fakeDns: true);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(const DnsSettings()));
    });
  });

  group('isFakeDnsSupported', () {
    test('only on Android: the iOS tunnel extension has a 50 MB cap', () {
      expect(isFakeDnsSupported(TargetPlatform.android), isTrue);
      expect(isFakeDnsSupported(TargetPlatform.iOS), isFalse);
      expect(isFakeDnsSupported(TargetPlatform.windows), isFalse);
    });
  });
}
