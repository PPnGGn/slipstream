import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slipstream/features/dns/data/direct_dns.dart';
import 'package:slipstream/features/dns/data/dns_settings.dart';
import 'package:slipstream/features/dns/data/dns_settings_store.dart';
import 'package:slipstream/features/dns/data/remote_dns.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<DnsSettingsStore> storeWith(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    return DnsSettingsStore(await SharedPreferences.getInstance());
  }

  test('fresh install loads the defaults', () async {
    final store = await storeWith({});
    expect(store.load(), const DnsSettings());
  });

  test('save round-trips', () async {
    final store = await storeWith({});
    const settings = DnsSettings(
      remote: RemoteDns.cloudflare,
      direct: DirectDns.system,
      fakeDns: true,
    );
    await store.save(settings);
    expect(store.load(), settings);
  });

  test('is stored under the documented keys', () async {
    final store = await storeWith({});
    await store.save(
      const DnsSettings(
        remote: RemoteDns.xray,
        direct: DirectDns.system,
        fakeDns: true,
      ),
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('dns_remote'), 'xray');
    expect(prefs.getString('dns_direct'), 'system');
    expect(prefs.getBool('dns_fake_dns'), isTrue);
  });

  test('reads values stored by an earlier run', () async {
    final store = await storeWith({
      'dns_remote': 'cloudflare',
      'dns_direct': 'system',
      'dns_fake_dns': true,
    });
    expect(
      store.load(),
      const DnsSettings(
        remote: RemoteDns.cloudflare,
        direct: DirectDns.system,
        fakeDns: true,
      ),
    );
  });

  test('an unknown stored name falls back to that field\'s default', () async {
    final store = await storeWith({'dns_remote': 'quad9', 'dns_direct': 'isp'});
    expect(store.load(), const DnsSettings());
  });
}
