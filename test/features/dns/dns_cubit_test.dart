import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slipstream/features/dns/cubit/dns_cubit.dart';
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

  group('Fake DNS allowed (Android)', () {
    test('starts from the defaults on a fresh install', () async {
      final cubit = DnsCubit(store: await storeWith({}), fakeDnsAllowed: true);
      expect(cubit.state, const DnsSettings());
      expect(cubit.fakeDnsAllowed, isTrue);
    });

    test('starts from what the store holds', () async {
      final cubit = DnsCubit(
        store: await storeWith({
          'dns_remote': 'cloudflare',
          'dns_direct': 'system',
          'dns_fake_dns': true,
        }),
        fakeDnsAllowed: true,
      );
      expect(
        cubit.state,
        const DnsSettings(
          remote: RemoteDns.cloudflare,
          direct: DirectDns.system,
          fakeDns: true,
        ),
      );
    });

    test('setRemote emits and stores, other fields stay', () async {
      final store = await storeWith({'dns_fake_dns': true});
      final cubit = DnsCubit(store: store, fakeDnsAllowed: true);
      await cubit.setRemote(RemoteDns.xray);
      const expected = DnsSettings(remote: RemoteDns.xray, fakeDns: true);
      expect(cubit.state, expected);
      expect(store.load(), expected);
    });

    test('setDirect emits and stores, other fields stay', () async {
      final store = await storeWith({'dns_remote': 'cloudflare'});
      final cubit = DnsCubit(store: store, fakeDnsAllowed: true);
      await cubit.setDirect(DirectDns.system);
      const expected = DnsSettings(
        remote: RemoteDns.cloudflare,
        direct: DirectDns.system,
      );
      expect(cubit.state, expected);
      expect(store.load(), expected);
    });

    test('setFakeDns emits and stores', () async {
      final store = await storeWith({});
      final cubit = DnsCubit(store: store, fakeDnsAllowed: true);
      await cubit.setFakeDns(enabled: true);
      expect(cubit.state.fakeDns, isTrue);
      expect(store.load().fakeDns, isTrue);
      await cubit.setFakeDns(enabled: false);
      expect(cubit.state.fakeDns, isFalse);
      expect(store.load().fakeDns, isFalse);
    });

    test('a call that changes nothing emits nothing', () async {
      final cubit = DnsCubit(store: await storeWith({}), fakeDnsAllowed: true);
      final emitted = <DnsSettings>[];
      final sub = cubit.stream.listen(emitted.add);
      await cubit.setRemote(RemoteDns.google);
      await cubit.setDirect(DirectDns.yandex);
      await cubit.setFakeDns(enabled: false);
      await Future<void>.delayed(Duration.zero);
      expect(emitted, isEmpty);
      await sub.cancel();
    });
  });

  group('Fake DNS not allowed (iOS: 50 MB tunnel extension cap)', () {
    test('a stored Fake DNS flag loads as off', () async {
      final cubit = DnsCubit(
        store: await storeWith({'dns_fake_dns': true}),
        fakeDnsAllowed: false,
      );
      expect(cubit.state.fakeDns, isFalse);
      expect(cubit.fakeDnsAllowed, isFalse);
    });

    test('setFakeDns(true) changes and stores nothing', () async {
      final store = await storeWith({});
      final cubit = DnsCubit(store: store, fakeDnsAllowed: false);
      await cubit.setFakeDns(enabled: true);
      expect(cubit.state.fakeDns, isFalse);
      expect(store.load().fakeDns, isFalse);
    });

    test('the resolvers can still be picked', () async {
      final store = await storeWith({});
      final cubit = DnsCubit(store: store, fakeDnsAllowed: false);
      await cubit.setRemote(RemoteDns.cloudflare);
      expect(cubit.state.remote, RemoteDns.cloudflare);
      expect(store.load().remote, RemoteDns.cloudflare);
    });
  });
}
