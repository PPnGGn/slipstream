import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream/core/models/vpn_server/vpn_server.dart';
import 'package:slipstream/features/subscriptions/data/server_identity.dart';

VpnServer _server(String id, {String? title}) => VpnServer(
  id: id,
  subscriptionId: 'sub',
  countryCode: 'NL',
  title: title ?? id,
  configJson: '{}',
);

void main() {
  group('serverKey', () {
    test('drops the position the provider gave the server', () {
      expect(serverKey('a.example:443:uuid:#7'), 'a.example:443:uuid');
    });

    test('is the same wherever the server stands', () {
      expect(
        serverKey('a.example:443:uuid:#0'),
        serverKey('a.example:443:uuid:#12'),
      );
    });

    test('leaves an id without a position as it is', () {
      expect(serverKey('plain'), 'plain');
    });
  });

  group('remapServerId', () {
    test('keeps an id that is still there', () {
      expect(
        remapServerId('a.example:443:uuid:#1', [
          _server('b.example:443:uuid:#0'),
          _server('a.example:443:uuid:#1'),
        ]),
        'a.example:443:uuid:#1',
      );
    });

    test('follows a server the provider moved to another position', () {
      expect(
        remapServerId('a.example:443:uuid:#0', [
          _server('new.example:443:uuid:#0'),
          _server('a.example:443:uuid:#1'),
        ]),
        'a.example:443:uuid:#1',
      );
    });

    test('is null when the server is gone', () {
      expect(
        remapServerId('a.example:443:uuid:#0', [
          _server('b.example:443:uuid:#0'),
        ]),
        isNull,
      );
    });

    test('does not match on a changed credential', () {
      expect(
        remapServerId('a.example:443:old-uuid:#0', [
          _server('a.example:443:new-uuid:#0'),
        ]),
        isNull,
      );
    });

    test('keeps the automatic server apart from the real one with the same '
        'address', () {
      // The provider's "Авто" shares host, port and credential with a real
      // server; only the position tells them apart, and it just shifted.
      // The old id still exists, but now it is the real server.
      expect(
        remapServerId('de:443:u:#0', [
          _server('de:443:u:#0', title: '🇩🇪 Germany'),
          _server('de:443:u:#1', title: '🚀 Авто | Лучший сервер'),
        ], oldTitle: '🚀 Авто | Лучший сервер'),
        'de:443:u:#1',
      );
      // The old id is gone, and the first match is the other server.
      expect(
        remapServerId('de:443:u:#1', [
          _server('de:443:u:#0', title: '🚀 Авто | Лучший сервер'),
          _server('de:443:u:#2', title: '🇩🇪 Germany'),
        ], oldTitle: '🇩🇪 Germany'),
        'de:443:u:#2',
      );
    });

    test('follows the automatic server when it moved to another address', () {
      // "Авто" points at the best server of the moment: after the refresh it
      // has a new address, and the old one belongs to a real server now.
      expect(
        remapServerId('de:443:u:#0', [
          _server('pl:443:u:#0', title: '🚀 Авто | Лучший сервер'),
          _server('pl:443:u:#1', title: '🇵🇱 Poland'),
          _server('de:443:u:#2', title: '🇩🇪 Germany'),
        ], oldTitle: '🚀 Авто | Лучший сервер'),
        'pl:443:u:#0',
      );
    });

    test('prefers the automatic server with the same title', () {
      expect(
        remapServerId('de:443:u:#0', [
          _server('pl:443:u:#0', title: 'Авто (fast)'),
          _server('pl:443:u:#1', title: 'Авто'),
        ], oldTitle: 'Авто'),
        'pl:443:u:#1',
      );
    });

    test('is null when the automatic server is gone, the real one stays', () {
      expect(
        remapServerId('de:443:u:#0', [
          _server('de:443:u:#1', title: '🇩🇪 Germany'),
        ], oldTitle: 'Авто'),
        isNull,
      );
    });

    test('does not turn a real server into the automatic one', () {
      // The real server is gone; "Авто" happens to point at its address.
      expect(
        remapServerId('de:443:u:#1', [
          _server('de:443:u:#0', title: 'Авто'),
        ], oldTitle: '🇩🇪 Germany'),
        isNull,
      );
    });

    test('keeps a renamed server when nothing else shares its address', () {
      expect(
        remapServerId('de:443:u:#0', [
          _server('de:443:u:#0', title: 'Germany 2'),
        ], oldTitle: 'Germany'),
        'de:443:u:#0',
      );
    });

    test('prefers the same title among servers with one address', () {
      expect(
        remapServerId('de:443:u:#0', [
          _server('de:443:u:#1', title: 'Germany A'),
          _server('de:443:u:#2', title: 'Germany B'),
        ], oldTitle: 'Germany B'),
        'de:443:u:#2',
      );
    });

    test('falls back to the first match when the title is not known', () {
      expect(
        remapServerId('de:443:u:#0', [
          _server('de:443:u:#1', title: 'Germany'),
          _server('de:443:u:#2', title: 'Авто'),
        ]),
        'de:443:u:#1',
      );
    });

    test('works for ids without a position suffix', () {
      expect(remapServerId('plain', [_server('plain')]), 'plain');
      expect(remapServerId('plain', [_server('other')]), isNull);
    });
  });
}
