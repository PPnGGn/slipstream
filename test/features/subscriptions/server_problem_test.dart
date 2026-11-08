import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream/core/models/vpn_server/vpn_server.dart';
import 'package:slipstream/features/subscriptions/data/server_problem.dart';

import 'reality_fixtures.dart';

void main() {
  group('serverProblem', () {
    test('REALITY with a public key is fine', () {
      expect(serverProblem(realityServerWithKey()), isNull);
    });

    test('REALITY with the key under the newer name "password" is fine', () {
      expect(serverProblem(realityServerWithKey(keyField: 'password')), isNull);
    });

    test('REALITY without a key is a problem', () {
      expect(
        serverProblem(realityServerWithoutKey()),
        ServerProblem.realityWithoutKey,
      );
    });

    test('REALITY with empty keys is a problem too', () {
      final server = serverWithStream({
        'security': 'reality',
        'realitySettings': {'publicKey': '', 'password': '', 'shortId': '0'},
      });
      expect(serverProblem(server), ServerProblem.realityWithoutKey);
    });

    test('REALITY with no settings block at all is a problem', () {
      final server = serverWithStream({'security': 'reality'});
      expect(serverProblem(server), ServerProblem.realityWithoutKey);
    });

    test('other security modes are not judged', () {
      expect(serverProblem(serverWithStream({'security': 'tls'})), isNull);
      expect(serverProblem(serverWithStream({'security': 'none'})), isNull);
      expect(serverProblem(serverWithStream({'network': 'hysteria'})), isNull);
    });

    test('a config that is not readable is not this problem', () {
      const broken = VpnServer(
        id: 'x',
        subscriptionId: 'sub',
        countryCode: 'NL',
        title: 'Broken',
        configJson: 'not json',
      );
      expect(serverProblem(broken), isNull);
    });

    test('a config without a proxy outbound is not this problem', () {
      const none = VpnServer(
        id: 'x',
        subscriptionId: 'sub',
        countryCode: 'NL',
        title: 'None',
        configJson: '{"outbounds":[{"tag":"direct","protocol":"freedom"}]}',
      );
      expect(serverProblem(none), isNull);
    });
  });

  group('sinkBrokenServers', () {
    VpnServer good(String id) =>
        realityServerWithKey().copyWith(id: id, title: id);
    VpnServer broken(String id) =>
        realityServerWithoutKey().copyWith(id: id, title: id);

    test('puts the broken ones last and keeps the order of each part', () {
      final sunk = sinkBrokenServers([
        broken('b1'),
        good('g1'),
        broken('b2'),
        good('g2'),
      ]);

      expect(sunk.map((s) => s.id), ['g1', 'g2', 'b1', 'b2']);
    });

    test('with nothing broken the list comes back as it is', () {
      final servers = [good('g1'), good('g2')];

      expect(identical(sinkBrokenServers(servers), servers), isTrue);
    });

    test('an all-broken list keeps its order', () {
      final sunk = sinkBrokenServers([broken('b1'), broken('b2')]);

      expect(sunk.map((s) => s.id), ['b1', 'b2']);
    });
  });
}
