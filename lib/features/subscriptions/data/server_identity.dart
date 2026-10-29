import 'package:slipstream/core/models/vpn_server/vpn_server.dart';
import 'package:slipstream/features/subscriptions/data/auto_server.dart';

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
///
/// The provider's automatic server ("Авто") is not an address, it is a role:
/// it points at the best server of the moment, so it shares the key of a real
/// server and changes that key between refreshes. So when [oldTitle] (the
/// title the server had before the refresh) is given:
/// - an automatic server is followed by its kind and title, wherever it points
///   now: the old address belongs to a real server by then;
/// - a real server is never mapped to an automatic one, and the old id is not
///   trusted on its own, it may be the automatic one's by now.
String? remapServerId(
  String oldId,
  List<VpnServer> servers, {
  String? oldTitle,
}) {
  final wantAuto = oldTitle == null ? null : isAutoTitle(oldTitle);
  final sameKind = wantAuto == null
      ? servers
      : servers.where((s) => isAutoTitle(s.title) == wantAuto);

  final key = serverKey(oldId);
  final matches = wantAuto == true
      ? sameKind
      : sameKind.where((s) => serverKey(s.id) == key);
  // Whoever has the old id goes first, so it wins every tie.
  final candidates = [
    ...matches.where((s) => s.id == oldId),
    ...matches.where((s) => s.id != oldId),
  ];
  if (candidates.isEmpty) return null;

  if (oldTitle != null) {
    final byTitle = candidates.where((s) => s.title == oldTitle);
    if (byTitle.isNotEmpty) return byTitle.first.id;
  }
  return candidates.first.id;
}
