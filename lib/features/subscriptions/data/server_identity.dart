import 'package:slipstream/core/models/vpn_server/vpn_server.dart';

/// The `:#N` tail every parser appends: the server's position in the
/// subscription body, there only to keep ids unique.
final _positionSuffix = RegExp(r':#\d+$');

/// The id without its position: what stays the same when a provider moves
/// the server (same host, port and credential). Favorites are kept by it.
String serverKey(String id) => id.replaceFirst(_positionSuffix, '');

/// Finds [oldId] in [servers] after a refresh. Server ids end with the
/// server's position, so a provider that reorders or adds servers changes
/// the id of a server that is otherwise the same (same host, port and
/// credential). Returns that server's new id, or null if it is gone.
String? remapServerId(String oldId, List<VpnServer> servers) {
  if (servers.any((s) => s.id == oldId)) return oldId;
  final key = serverKey(oldId);
  for (final server in servers) {
    if (serverKey(server.id) == key) return server.id;
  }
  return null;
}
