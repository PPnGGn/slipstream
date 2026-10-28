import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream/core/models/vpn_server/vpn_server.dart';
import 'package:slipstream/features/subscriptions/data/auto_server.dart';

VpnServer _server(String id, String title) => VpnServer(
  id: id,
  subscriptionId: 'sub',
  countryCode: 'NL',
  title: title,
  configJson: '{}',
);

List<String> _ids(List<VpnServer> servers) => [for (final s in servers) s.id];

void main() {
  group('isAutoTitle', () {
    test('recognizes the provider\'s automatic choice', () {
      for (final title in [
        '🇪🇺 🚀Авто | Лучший сервер ⚡⚡',
        'Auto',
        'AUTO select',
        'Авто',
        'Автовыбор',
        '⚡ Лучший сервер',
        'Best server',
        'Fastest',
        'Auto-select',
        '🌐 авто',
      ]) {
        expect(isAutoTitle(title), isTrue, reason: title);
      }
    });

    test('does not take ordinary servers for it', () {
      for (final title in [
        '🇨🇭⚡Швейцария-1',
        'Автобус',
        'AutoVPN',
        'Automatic Frankfurt',
        'Faster Germany',
        '',
      ]) {
        expect(isAutoTitle(title), isFalse, reason: title);
      }
    });
  });

  group('pinAutoServers', () {
    test('puts automatic servers first, the rest keep their order', () {
      final pinned = pinAutoServers([
        _server('a', 'Germany'),
        _server('b', 'Auto'),
        _server('c', 'France'),
        _server('d', 'Авто | Лучший сервер'),
      ]);

      expect(_ids(pinned), ['b', 'd', 'a', 'c']);
    });

    test('no automatic server changes nothing', () {
      final servers = [_server('a', 'Germany'), _server('b', 'France')];

      expect(_ids(pinAutoServers(servers)), ['a', 'b']);
    });

    test('does not touch the list it was given', () {
      final servers = [_server('a', 'Germany'), _server('b', 'Auto')];

      pinAutoServers(servers);

      expect(_ids(servers), ['a', 'b']);
    });
  });
}
