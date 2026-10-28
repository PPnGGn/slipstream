import 'package:slipstream/core/models/vpn_server/vpn_server.dart';
import 'package:slipstream/features/subscriptions/data/server_identity.dart';

/// Whether [server] is one of the subscription's favorites. [favoriteIds]
/// hold whole server ids, like the selected server does: the position at the
/// end of an id is what tells apart two entries of one panel that share the
/// host, the port and the credential ("Auto" and a real server, say).
bool isFavorite(VpnServer server, List<String> favoriteIds) =>
    favoriteIds.contains(server.id);

/// [servers] with the favorites first. Both groups keep the order they came
/// in, so it works on a list already sorted by ping: favorites are sorted
/// among themselves and still stand on top.
List<VpnServer> pinFavorites(
  List<VpnServer> servers,
  List<String> favoriteIds,
) {
  if (favoriteIds.isEmpty) return servers;
  return [
    ...servers.where((s) => isFavorite(s, favoriteIds)),
    ...servers.where((s) => !isFavorite(s, favoriteIds)),
  ];
}

/// [ids] without [id] if it is there, with it otherwise.
List<String> toggleFavoriteId(List<String> ids, String id) =>
    ids.contains(id) ? [...ids.where((i) => i != id)] : [...ids, id];

/// Carries the favorites over a refresh, which can give every server a new
/// position and so a new id. The same id in [after] is not enough: a server
/// moved down by one leaves its old id to its neighbour. So the favorite is,
/// in this order:
///  1. the server with the same id and the same title;
///  2. the only server with the same address (host, port, credential);
///  3. the only one of those with the same title.
/// A favorite that cannot be placed with certainty is dropped: a wrong server
/// pinned is worse than a lost pin.
List<String> remapFavoriteIds(
  List<String> favoriteIds,
  List<VpnServer> before,
  List<VpnServer> after,
) {
  final titles = {for (final s in before) s.id: s.title};
  final result = <String>[];

  void keep(String id) {
    if (!result.contains(id)) result.add(id);
  }

  for (final id in favoriteIds) {
    final title = titles[id];
    if (title == null) continue;

    if (after.any((s) => s.id == id && s.title == title)) {
      keep(id);
      continue;
    }
    final key = serverKey(id);
    final sameAddress = after.where((s) => serverKey(s.id) == key).toList();
    if (sameAddress.length == 1) {
      keep(sameAddress.single.id);
      continue;
    }
    final sameTitle = sameAddress.where((s) => s.title == title).toList();
    if (sameTitle.length == 1) keep(sameTitle.single.id);
  }
  return result;
}
