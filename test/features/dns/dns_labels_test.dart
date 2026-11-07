import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream/features/dns/data/direct_dns.dart';
import 'package:slipstream/features/dns/data/dns_settings.dart';
import 'package:slipstream/features/dns/data/remote_dns.dart';
import 'package:slipstream/features/dns/ui/dns_labels.dart';
import 'package:slipstream/features/routing/data/ru_bypass_mode.dart';

void main() {
  group('remote resolver rows', () {
    test('titles', () {
      expect(remoteDnsTitle(RemoteDns.cloudflare), 'Cloudflare DoH');
      expect(remoteDnsTitle(RemoteDns.google), 'Google DoH');
      expect(remoteDnsTitle(RemoteDns.xray), 'Xray built-in');
    });

    test('a DoH subtitle is the address the config really uses', () {
      // The page used to show cloudflare-dns.com and dns.google while the
      // config said an IP; the row must tell what actually happens.
      expect(
        remoteDnsSubtitle(RemoteDns.cloudflare),
        RemoteDns.cloudflare.address,
      );
      expect(remoteDnsSubtitle(RemoteDns.google), RemoteDns.google.address);
    });

    test('the built-in one says it is plain UDP through the tunnel', () {
      expect(remoteDnsSubtitle(RemoteDns.xray), 'UDP 1.1.1.1:53 VIA TUNNEL');
    });
  });

  group('direct resolver rows', () {
    test('titles', () {
      expect(directDnsTitle(DirectDns.yandex), 'Yandex DNS');
      expect(directDnsTitle(DirectDns.system), 'System resolver');
    });

    test('subtitles', () {
      expect(directDnsSubtitle(DirectDns.yandex), DirectDns.yandex.address);
      expect(
        directDnsSubtitle(DirectDns.system),
        'The phone\'s own DNS, usually the operator\'s',
      );
    });

    test('the section is live only while the RU bypass is on', () {
      expect(directDnsActive(RuBypassMode.bypassRu), isTrue);
      expect(directDnsActive(RuBypassMode.off), isFalse);
    });

    test('an inactive section explains itself, an active one is silent', () {
      expect(directDnsHint(active: true), isNull);
      expect(directDnsHint(active: false), contains('RU bypass'));
    });
  });

  group('Fake DNS row', () {
    test('subtitle follows the switch', () {
      expect(fakeDnsSubtitle(enabled: true), contains('made-up'));
      expect(fakeDnsSubtitle(enabled: false), startsWith('Off'));
    });
  });

  group('dnsSummary (the row in Settings)', () {
    test('defaults', () {
      expect(dnsSummary(const DnsSettings()), 'Google DoH');
    });

    test('names the remote resolver', () {
      expect(
        dnsSummary(const DnsSettings(remote: RemoteDns.cloudflare)),
        'Cloudflare DoH',
      );
      expect(
        dnsSummary(const DnsSettings(remote: RemoteDns.xray)),
        'Xray built-in',
      );
    });

    test('adds Fake DNS when it is on', () {
      expect(
        dnsSummary(const DnsSettings(fakeDns: true)),
        'Google DoH · Fake DNS',
      );
    });

    test('the direct resolver is not part of it', () {
      // It matters only with the RU bypass, which has its own row.
      expect(
        dnsSummary(const DnsSettings(direct: DirectDns.system)),
        'Google DoH',
      );
    });
  });
}
