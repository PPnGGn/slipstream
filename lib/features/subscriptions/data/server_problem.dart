import 'dart:convert';

import 'package:slipstream/core/models/vpn_server/vpn_server.dart';

/// Why a server cannot work, found in its config before anything starts.
enum ServerProblem {
  /// A REALITY server whose config has no public key (neither `publicKey` nor
  /// `password`). The provider's subscription came without it; the core refuses
  /// to build such a config (`empty "password"`), so a start only fails.
  realityWithoutKey,
}

/// The problem [server]'s config has, or null when it looks usable. Judges only
/// what is certain to fail; a config it cannot read is left for the core to say.
ServerProblem? serverProblem(VpnServer server) {
  final Object? config;
  try {
    config = jsonDecode(server.configJson);
  } catch (_) {
    return null;
  }
  if (config is! Map) return null;

  final outbounds = config['outbounds'];
  if (outbounds is! List) return null;
  // The parsers tag the exit `proxy`, whatever the provider called it.
  for (final outbound in outbounds) {
    if (outbound is! Map || outbound['tag'] != 'proxy') continue;
    final stream = outbound['streamSettings'];
    if (stream is! Map || stream['security'] != 'reality') return null;
    return _hasRealityKey(stream['realitySettings'])
        ? null
        : ServerProblem.realityWithoutKey;
  }
  return null;
}

bool _hasRealityKey(Object? settings) {
  if (settings is! Map) return false;
  bool filled(Object? value) => value is String && value.isNotEmpty;
  return filled(settings['publicKey']) || filled(settings['password']);
}

/// [servers] with the ones that cannot connect last. Both parts keep their
/// order, so it goes after the ping sort, the favorites and the automatic
/// server: a broken server has no place among them.
List<VpnServer> sinkBrokenServers(List<VpnServer> servers) {
  if (!servers.any((s) => serverProblem(s) != null)) return servers;
  return [
    ...servers.where((s) => serverProblem(s) == null),
    ...servers.where((s) => serverProblem(s) != null),
  ];
}
