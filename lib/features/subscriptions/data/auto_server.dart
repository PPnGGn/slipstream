import 'package:slipstream/core/models/vpn_server/vpn_server.dart';

// Whole words only, with anything that is not a letter or a digit around
// them (flags, emoji, "|", "-"): "Автобус" and "AutoVPN" are not it.
final _autoWord = RegExp(
  r'(^|[^\p{L}\p{N}])'
  r'(авто|автовыбор|auto|лучший сервер|best server|fastest)'
  r'($|[^\p{L}\p{N}])',
  unicode: true,
  caseSensitive: false,
);

/// Whether a server's [title] says it is the provider's automatic choice
/// ("🚀Авто | Лучший сервер"). Its config is an ordinary server's, there is
/// nothing but the name to go by.
bool isAutoTitle(String title) => _autoWord.hasMatch(title);

/// [servers] with the automatic ones first. The rest keep their order, so it
/// goes after the ping sort and the favorites: the automatic server shares
/// its address, and so its ping, with a real server, and has no place in
/// either of them.
List<VpnServer> pinAutoServers(List<VpnServer> servers) {
  if (!servers.any((s) => isAutoTitle(s.title))) return servers;
  return [
    ...servers.where((s) => isAutoTitle(s.title)),
    ...servers.where((s) => !isAutoTitle(s.title)),
  ];
}
