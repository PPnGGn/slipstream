import 'package:flutter_test/flutter_test.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:slipstream/features/routing/data/local_proxy_client.dart';
import 'package:slipstream/features/vpn/data/vpn_api.g.dart';

/// Only localProxy() is exercised; anything else would be a test bug.
class _FakeConnection implements VpnConnection {
  _FakeConnection(this._answer);
  final Future<LocalProxyMessage?> Function() _answer;

  @override
  Future<LocalProxyMessage?> localProxy() => _answer();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final proxy = LocalProxyMessage(port: 2222, user: 'u1', pass: 'p1');

  test('proxyDirective embeds credentials for Dart to authenticate with', () {
    expect(proxyDirective(proxy), 'PROXY u1:p1@127.0.0.1:2222');
  });

  test('current() returns what the core reports', () async {
    final provider = LocalProxyProvider(
      _FakeConnection(() async => proxy),
      Talker(),
    );
    final got = await provider.current();
    expect(got?.port, 2222);
    expect(got?.user, 'u1');
    expect(got?.pass, 'p1');
  });

  test('current() is null while no tunnel is up', () async {
    final provider = LocalProxyProvider(
      _FakeConnection(() async => null),
      Talker(),
    );
    expect(await provider.current(), isNull);
  });

  test('a channel error falls back to direct instead of throwing', () async {
    final provider = LocalProxyProvider(
      _FakeConnection(() async => throw Exception('channel down')),
      Talker(),
    );
    expect(await provider.current(), isNull);
  });
}
