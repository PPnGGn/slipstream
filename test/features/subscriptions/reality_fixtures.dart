import 'dart:convert';

import 'package:slipstream/core/models/vpn_server/vpn_server.dart';

/// A server whose proxy outbound has the given stream settings. The shape is
/// the one the subscription parsers produce: the exit is tagged `proxy`.
VpnServer serverWithStream(
  Map<String, Object?> stream, {
  String id = 'srv',
  String protocol = 'vless',
}) => VpnServer(
  id: id,
  subscriptionId: 'sub',
  countryCode: 'NL',
  title: 'Amsterdam',
  configJson: jsonEncode({
    'outbounds': [
      {'tag': 'proxy', 'protocol': protocol, 'streamSettings': stream},
      {'tag': 'direct', 'protocol': 'freedom'},
    ],
  }),
);

const _realityBase = {
  'serverName': 'example.com',
  'shortId': '0123',
  'fingerprint': 'chrome',
};

/// REALITY with its public key, the way a working subscription has it.
VpnServer realityServerWithKey({String keyField = 'publicKey'}) =>
    serverWithStream({
      'network': 'tcp',
      'security': 'reality',
      'realitySettings': {..._realityBase, keyField: 'some-public-key'},
    });

/// REALITY with no key at all: what the provider's subscription sends and the
/// core refuses to build (`empty "password"`).
VpnServer realityServerWithoutKey() => serverWithStream({
  'network': 'tcp',
  'security': 'reality',
  'realitySettings': _realityBase,
});
