import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream/features/security/data/obfuscation_settings.dart';
import 'package:slipstream/features/vpn/data/obfuscation_gate.dart';

void main() {
  const fragmentOn = ObfuscationSettings(fragmentEnabled: true);
  const noiseOn = ObfuscationSettings(noiseEnabled: true);
  const bothOn = ObfuscationSettings(fragmentEnabled: true, noiseEnabled: true);

  /// A config whose `proxy` outbound runs over [network]; [stream] is merged
  /// into its streamSettings (finalmask, for the cases that start with masks).
  String configOn(String network, {Map<String, dynamic>? stream}) => jsonEncode({
    'outbounds': [
      {
        'tag': 'proxy',
        'protocol': 'vless',
        'streamSettings': {'network': network, ...?stream},
      },
      {'tag': 'direct', 'protocol': 'freedom'},
    ],
  });

  Map<String, dynamic> proxyOf(String configJson) {
    final config = jsonDecode(configJson) as Map<String, dynamic>;
    return (config['outbounds'] as List).cast<Map<String, dynamic>>().firstWhere(
      (o) => o['tag'] == 'proxy',
    );
  }

  Map<String, dynamic>? finalmaskOf(String configJson) =>
      (proxyOf(configJson)['streamSettings'] as Map<String, dynamic>?)?['finalmask']
          as Map<String, dynamic>?;

  const fragmentMask = {
    'type': 'fragment',
    'settings': {'packets': 'tlshello', 'length': '100-200', 'delay': '10-20'},
  };
  const noiseMask = {
    'type': 'noise',
    'settings': {
      'noise': [
        {'rand': '10-20', 'delay': '10-16'},
      ],
    },
  };

  group('with both options off', () {
    test('the config goes through as the very same string', () {
      final config = configOn('tcp');

      expect(
        applyObfuscation(config, const ObfuscationSettings()),
        same(config),
      );
    });
  });

  group('Fragment', () {
    test('adds a fragment mask to the tcp side of a TCP server', () {
      final result = applyObfuscation(configOn('tcp'), fragmentOn);

      expect(finalmaskOf(result)!['tcp'], equals([fragmentMask]));
      expect(finalmaskOf(result)!.containsKey('udp'), isFalse);
    });

    test('writes the values of the settings into the mask', () {
      final result = applyObfuscation(
        configOn('tcp'),
        const ObfuscationSettings(
          fragmentEnabled: true,
          fragment: FragmentParams(packets: '1-3', length: '50-90', delay: '5-9'),
        ),
      );

      expect(
        finalmaskOf(result)!['tcp'],
        equals([
          {
            'type': 'fragment',
            'settings': {'packets': '1-3', 'length': '50-90', 'delay': '5-9'},
          },
        ]),
      );
    });

    test('applies to every transport that runs over a TCP connection', () {
      for (final network in ['tcp', 'raw', 'ws', 'grpc', 'httpupgrade', 'xhttp']) {
        final result = applyObfuscation(configOn(network), fragmentOn);

        expect(finalmaskOf(result)?['tcp'], isNotNull, reason: network);
      }
    });

    test('treats a stream with no network as tcp, which is the xray default', () {
      final config = jsonEncode({
        'outbounds': [
          {
            'tag': 'proxy',
            'protocol': 'vless',
            'streamSettings': {'security': 'reality'},
          },
        ],
      });

      expect(finalmaskOf(applyObfuscation(config, fragmentOn))?['tcp'], isNotNull);
    });

    test('leaves UDP transports alone: there is no TLS hello to cut', () {
      for (final network in ['kcp', 'hysteria']) {
        final config = configOn(network);

        expect(applyObfuscation(config, fragmentOn), same(config), reason: network);
      }
    });

    test('keeps the masks a server already brings', () {
      final config = configOn(
        'tcp',
        stream: {
          'finalmask': {
            'tcp': [
              {'type': 'header-custom', 'settings': {}},
            ],
          },
        },
      );

      expect(applyObfuscation(config, fragmentOn), same(config));
    });
  });

  group('Noise', () {
    test('adds a noise mask to the udp side of a UDP server', () {
      for (final network in ['kcp', 'hysteria']) {
        final result = applyObfuscation(configOn(network), noiseOn);

        expect(finalmaskOf(result)!['udp'], equals([noiseMask]), reason: network);
        expect(finalmaskOf(result)!.containsKey('tcp'), isFalse, reason: network);
      }
    });

    test('writes the values of the settings into the mask', () {
      final result = applyObfuscation(
        configOn('kcp'),
        const ObfuscationSettings(
          noiseEnabled: true,
          noise: NoiseParams(size: '33-33', delay: '1-2'),
        ),
      );

      expect(
        finalmaskOf(result)!['udp'],
        equals([
          {
            'type': 'noise',
            'settings': {
              'noise': [
                {'rand': '33-33', 'delay': '1-2'},
              ],
            },
          },
        ]),
      );
    });

    test('goes first, nearest to the wire, ahead of the Hysteria2 salamander', () {
      final config = configOn(
        'hysteria',
        stream: {
          'finalmask': {
            'udp': [
              {
                'type': 'salamander',
                'settings': {'password': 'obfs'},
              },
            ],
            'quicParams': {
              'udpHop': {'ports': '20000-30000'},
            },
          },
        },
      );

      final mask = finalmaskOf(applyObfuscation(config, noiseOn))!;

      expect((mask['udp'] as List).map((m) => (m as Map)['type']), ['noise', 'salamander']);
      expect(
        mask['quicParams'],
        equals({
          'udpHop': {'ports': '20000-30000'},
        }),
      );
    });

    test('leaves TCP transports alone: noise is for datagrams', () {
      final config = configOn('tcp');

      expect(applyObfuscation(config, noiseOn), same(config));
    });

    test('keeps the masks a server already brings, but salamander', () {
      final config = configOn(
        'kcp',
        stream: {
          'finalmask': {
            'udp': [
              {'type': 'header-custom', 'settings': {}},
            ],
          },
        },
      );

      expect(applyObfuscation(config, noiseOn), same(config));
    });

    test('does not add a second noise mask', () {
      final config = configOn(
        'kcp',
        stream: {
          'finalmask': {
            'udp': [noiseMask],
          },
        },
      );

      expect(applyObfuscation(config, noiseOn), same(config));
    });
  });

  group('both options', () {
    test('each goes where it works, for a TCP server and for a UDP one', () {
      final tcp = applyObfuscation(configOn('ws'), bothOn);
      final udp = applyObfuscation(configOn('hysteria'), bothOn);

      expect(finalmaskOf(tcp)!['tcp'], equals([fragmentMask]));
      expect(finalmaskOf(tcp)!.containsKey('udp'), isFalse);
      expect(finalmaskOf(udp)!['udp'], equals([noiseMask]));
      expect(finalmaskOf(udp)!.containsKey('tcp'), isFalse);
    });

    test('applying twice gives what applying once gives', () {
      final once = applyObfuscation(configOn('tcp'), bothOn);

      expect(applyObfuscation(once, bothOn), same(once));
    });
  });

  group('what it never touches', () {
    test('the other outbounds', () {
      final result = applyObfuscation(configOn('tcp'), bothOn);
      final config = jsonDecode(result) as Map<String, dynamic>;
      final direct = (config['outbounds'] as List).cast<Map<String, dynamic>>().last;

      expect(direct, equals({'tag': 'direct', 'protocol': 'freedom'}));
    });

    test('the rest of the proxy outbound', () {
      final result = applyObfuscation(configOn('tcp', stream: {'security': 'reality'}), fragmentOn);
      final stream = proxyOf(result)['streamSettings'] as Map<String, dynamic>;

      expect(stream['security'], equals('reality'));
      expect(stream['network'], equals('tcp'));
      expect(proxyOf(result)['protocol'], equals('vless'));
    });

    test('a proxy outbound that has no stream settings', () {
      final config = jsonEncode({
        'outbounds': [
          {'tag': 'proxy', 'protocol': 'freedom'},
        ],
      });

      expect(applyObfuscation(config, bothOn), same(config));
    });

    test('a config that has no proxy outbound', () {
      final config = jsonEncode({
        'outbounds': [
          {
            'tag': 'other',
            'protocol': 'vless',
            'streamSettings': {'network': 'tcp'},
          },
        ],
      });

      expect(applyObfuscation(config, bothOn), same(config));
    });

    test('text that is not a config, which comes back unchanged and never throws', () {
      for (final broken in ['', 'not json', '[]', '{"outbounds": 5}']) {
        expect(applyObfuscation(broken, bothOn), same(broken), reason: broken);
      }
    });
  });
}
