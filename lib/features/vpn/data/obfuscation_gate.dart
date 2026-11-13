import 'dart:convert';

import 'package:slipstream/features/security/data/obfuscation_settings.dart';

// Transports that run over a TCP connection. xray hands that connection to the
// tcp masks right after dialing, before TLS or REALITY start, so a fragment
// mask cuts the TLS hello itself. `raw` is the new name of `tcp`; a stream
// with no network is tcp.
const _tcpNetworks = {
  'tcp',
  'raw',
  'ws',
  'websocket',
  'grpc',
  'gun',
  'httpupgrade',
  'xhttp',
  'splithttp',
};

// Transports that run over UDP datagrams, which get the udp masks.
const _udpNetworks = {'kcp', 'mkcp', 'hysteria'};

// The only udp mask the app itself writes next to Noise (Hysteria2 obfuscation,
// see XrayConfigBuilder.buildHysteria2). Any other mask is the provider's.
const _ownUdpMasks = {'salamander'};

/// Adds the Fragment and Noise masks to the `proxy` outbound of [configJson],
/// for the servers they work for: Fragment to a server that runs over TCP,
/// Noise to one that runs over UDP.
///
/// Both are `streamSettings.finalmask` masks, not a second outbound: xray
/// itself calls the `fragment` of the freedom outbound deprecated in favour of
/// them, and a mask needs no `dialerProxy` chain. The config comes back as the
/// very same string when nothing changes: both options off, a transport the
/// option does not fit, a server that already carries its own masks (they stay
/// as the provider wrote them; an unknown mask in front of ours could break the
/// connection), or text that is not a config.
String applyObfuscation(String configJson, ObfuscationSettings settings) {
  if (!settings.fragmentEnabled && !settings.noiseEnabled) return configJson;

  final Object? decoded;
  try {
    decoded = jsonDecode(configJson);
  } catch (_) {
    return configJson;
  }
  if (decoded is! Map<String, dynamic>) return configJson;
  final outbounds = decoded['outbounds'];
  if (outbounds is! List) return configJson;

  var changed = false;
  for (final outbound in outbounds) {
    if (outbound is! Map<String, dynamic> || outbound['tag'] != 'proxy') {
      continue;
    }
    final stream = outbound['streamSettings'];
    if (stream is! Map<String, dynamic>) continue;
    changed |= _applyTo(stream, settings);
  }
  return changed ? jsonEncode(decoded) : configJson;
}

bool _applyTo(Map<String, dynamic> stream, ObfuscationSettings settings) {
  final rawNetwork = stream['network'];
  final network = (rawNetwork is String ? rawNetwork : 'tcp').toLowerCase();

  final existing = stream['finalmask'];
  if (existing != null && existing is! Map<String, dynamic>) return false;
  final finalmask = (existing as Map<String, dynamic>?) ?? <String, dynamic>{};

  var changed = false;
  if (settings.fragmentEnabled &&
      _tcpNetworks.contains(network) &&
      _masksOf(finalmask['tcp']).isEmpty) {
    finalmask['tcp'] = [_fragmentMask(settings.fragment)];
    changed = true;
  }
  if (settings.noiseEnabled && _udpNetworks.contains(network)) {
    final masks = _masksOf(finalmask['udp']);
    final onlyOurs = masks.every((type) => _ownUdpMasks.contains(type));
    if (onlyOurs) {
      // First in the list. Measured against the real xray: next to salamander
      // the noise datagram is obfuscated like every other one (8 bytes longer),
      // so on the wire it is one more random-looking datagram ahead of QUIC.
      final rest = (finalmask['udp'] as List?) ?? const [];
      finalmask['udp'] = [_noiseMask(settings.noise), ...rest];
      changed = true;
    }
  }

  if (changed) stream['finalmask'] = finalmask;
  return changed;
}

/// The `type` of every mask in [list]; a mask that is not an object counts as
/// an unknown one.
List<String> _masksOf(Object? list) => [
  if (list is List)
    for (final mask in list)
      if (mask is Map<String, dynamic> && mask['type'] is String)
        mask['type'] as String
      else
        '?',
];

Map<String, dynamic> _fragmentMask(FragmentParams params) => {
  'type': 'fragment',
  'settings': {
    'packets': params.packets,
    'length': params.length,
    'delay': params.delay,
  },
};

Map<String, dynamic> _noiseMask(NoiseParams params) => {
  'type': 'noise',
  'settings': {
    'noise': [
      {'rand': params.size, 'delay': params.delay},
    ],
  },
};
