import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream/core/models/vpn_server/vpn_server.dart';
import 'package:slipstream/features/subscriptions/data/server_identity.dart';

VpnServer _server(String id) => VpnServer(
  id: id,
  subscriptionId: 'sub',
  countryCode: 'NL',
  title: id,
  configJson: '{}',
);

void main() {
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

    test('works for ids without a position suffix', () {
      expect(remapServerId('plain', [_server('plain')]), 'plain');
      expect(remapServerId('plain', [_server('other')]), isNull);
    });
  });
}
