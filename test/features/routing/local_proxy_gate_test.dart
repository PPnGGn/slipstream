import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:slipstream/features/routing/data/local_proxy_gate.dart';

void main() {
  final gate = LocalProxyGate(Talker());

  test('existing loopback http inbound — config untouched, its port returned', () {
    const src =
        '{"inbounds":[{"listen":"127.0.0.1","port":10809,"protocol":"http","tag":"http"}],'
        '"outbounds":[{"tag":"proxy"}]}';

    final (config, port) = gate.ensureHttpInbound(src);

    expect(port, 10809);
    expect(config, same(src));
  });

  test('http inbound on localhost / ::1 also counts', () {
    for (final host in ['localhost', '::1']) {
      final (config, port) = gate.ensureHttpInbound(
        jsonEncode({
          'inbounds': [
            {'listen': host, 'port': 18080, 'protocol': 'http'},
          ],
        }),
      );
      expect(port, 18080, reason: host);
      expect(jsonDecode(config)['inbounds'], hasLength(1), reason: host);
    }
  });

  test('http inbound bound to a non-loopback address is ignored, one is added', () {
    final (config, port) = gate.ensureHttpInbound(
      jsonEncode({
        'inbounds': [
          {'listen': '0.0.0.0', 'port': 3128, 'protocol': 'http'},
        ],
      }),
    );

    expect(port, 10809);
    final inbounds = (jsonDecode(config)['inbounds'] as List).cast<Map>();
    expect(inbounds, hasLength(2));
    expect(inbounds.last['listen'], '127.0.0.1');
    expect(inbounds.last['protocol'], 'http');
    expect(inbounds.last['port'], 10809);
  });

  test('no inbounds at all — one is injected on the fallback port', () {
    final (config, port) = gate.ensureHttpInbound(
      '{"outbounds":[{"tag":"proxy"}]}',
    );

    expect(port, 10809);
    final inbounds = (jsonDecode(config)['inbounds'] as List).cast<Map>();
    expect(inbounds.single['port'], 10809);
    expect(inbounds.single['tag'], 'geo-bootstrap-http');
  });

  test('fallback port is bumped past a collision', () {
    final (config, port) = gate.ensureHttpInbound(
      jsonEncode({
        'inbounds': [
          {'listen': '127.0.0.1', 'port': 10809, 'protocol': 'socks'},
          {'listen': '127.0.0.1', 'port': 10810, 'protocol': 'dokodemo-door'},
        ],
      }),
    );

    expect(port, 10811);
    final inbounds = (jsonDecode(config)['inbounds'] as List).cast<Map>();
    expect(inbounds, hasLength(3));
    expect(inbounds.last['port'], 10811);
  });

  test('undecodable config — returned as-is with the fallback port', () {
    const junk = 'not json';
    final (config, port) = gate.ensureHttpInbound(junk);
    expect(config, same(junk));
    expect(port, 10809);
  });
}
