import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream/core/models/vpn_server/vpn_server.dart';
import 'package:slipstream/features/subscriptions/data/favorite_servers.dart';

VpnServer _server(String id, {String? title}) => VpnServer(
  id: id,
  subscriptionId: 'sub',
  countryCode: 'NL',
  title: title ?? id,
  configJson: '{}',
);

List<String> _ids(List<VpnServer> servers) => [for (final s in servers) s.id];

void main() {
  group('pinFavorites', () {
    test('puts favorites first and keeps the order inside both groups', () {
      final pinned = pinFavorites(
        [
          _server('a:#0'),
          _server('b:#1'),
          _server('c:#2'),
          _server('d:#3'),
        ],
        ['d:#3', 'b:#1'],
      );

      expect(_ids(pinned), ['b:#1', 'd:#3', 'a:#0', 'c:#2']);
    });

    test('pins only the server itself, not one with the same address', () {
      // Two entries of one panel: the same host, port and credential, told
      // apart only by the position at the end of the id.
      final pinned = pinFavorites(
        [
          _server('h:443:u:#0'),
          _server('h:443:u:#1'),
          _server('h:443:u:#2'),
        ],
        ['h:443:u:#1'],
      );

      expect(_ids(pinned), ['h:443:u:#1', 'h:443:u:#0', 'h:443:u:#2']);
    });

    test('no favorites changes nothing', () {
      final servers = [_server('a:#0'), _server('b:#1')];

      expect(_ids(pinFavorites(servers, const [])), ['a:#0', 'b:#1']);
    });

    test('does not touch the list it was given', () {
      final servers = [_server('a:#0'), _server('b:#1')];

      pinFavorites(servers, ['b:#1']);

      expect(_ids(servers), ['a:#0', 'b:#1']);
    });
  });

  group('isFavorite', () {
    test('compares the whole id', () {
      expect(isFavorite(_server('h:443:u:#3'), ['h:443:u:#3']), isTrue);
      expect(isFavorite(_server('h:443:u:#4'), ['h:443:u:#3']), isFalse);
    });
  });

  group('toggleFavoriteId', () {
    test('adds an id that is not there', () {
      expect(toggleFavoriteId(['a'], 'b'), ['a', 'b']);
    });

    test('removes an id that is there', () {
      expect(toggleFavoriteId(['a', 'b'], 'a'), ['b']);
    });

    test('does not touch the list it was given', () {
      final ids = ['a'];

      toggleFavoriteId(ids, 'b');

      expect(ids, ['a']);
    });
  });

  group('remapFavoriteIds', () {
    test('keeps an id that is still there', () {
      final servers = [_server('a:#0'), _server('b:#1')];

      expect(remapFavoriteIds(['b:#1'], servers, servers), ['b:#1']);
    });

    test('follows a server the provider moved', () {
      final before = [_server('a:#0'), _server('b:#1')];
      final after = [_server('new:#0'), _server('a:#1'), _server('b:#2')];

      expect(remapFavoriteIds(['b:#1'], before, after), ['b:#2']);
    });

    test('tells servers of one address apart by title', () {
      final before = [
        _server('h:443:u:#0', title: 'Auto'),
        _server('h:443:u:#1', title: 'Germany'),
      ];
      final after = [
        _server('x:1:u:#0', title: 'Other'),
        _server('h:443:u:#1', title: 'Auto'),
        _server('h:443:u:#2', title: 'Germany'),
      ];

      expect(remapFavoriteIds(['h:443:u:#0'], before, after), ['h:443:u:#1']);
      expect(remapFavoriteIds(['h:443:u:#1'], before, after), ['h:443:u:#2']);
    });

    test('drops a favorite it cannot place with certainty', () {
      final before = [_server('h:443:u:#0', title: 'Auto')];
      final after = [
        _server('h:443:u:#1', title: 'Same'),
        _server('h:443:u:#2', title: 'Same'),
      ];

      expect(remapFavoriteIds(['h:443:u:#0'], before, after), isEmpty);
    });

    test('drops a server that is gone', () {
      final before = [_server('a:#0')];

      expect(remapFavoriteIds(['a:#0'], before, [_server('b:#0')]), isEmpty);
    });

    test('drops an id the old list never had', () {
      expect(remapFavoriteIds(['x:#0'], [_server('a:#0')], [_server('x:#1')]), isEmpty);
    });
  });
}
