import 'package:slipstream/core/models/vpn_server/vpn_server.dart';
import 'package:slipstream/features/ping/presentation/ping_entry.dart';

/// Orders servers for display once all rounds of a run finished
/// (spec: measured by latency ascending, then the rest in their
/// previous order — notTested/queued/measuring/unsupported go last,
/// dead below those because "confirmed dead" is more of a downgrade
/// than "never tried" or "can't be tried").
///
/// Never call this while a run is in flight: re-sorting under the
/// user's finger mid-measurement makes rows jump (spec, "Сортировка").
List<VpnServer> sortServersByPing(
  List<VpnServer> servers,
  Map<String, PingEntry> entries,
) {
  final measured = <MapEntry<VpnServer, PingEntry>>[];
  final untested = <VpnServer>[];
  final dead = <VpnServer>[];

  for (final server in servers) {
    final entry = entries[server.id];
    switch (entry?.status) {
      case PingRunStatus.measured:
        measured.add(MapEntry(server, entry!));
      case PingRunStatus.dead:
        dead.add(server);
      default:
        untested.add(server);
    }
  }

  measured.sort((a, b) {
    final byValue = (a.value.latencyMs ?? double.infinity).compareTo(
      b.value.latencyMs ?? double.infinity,
    );
    // Secondary key keeps equal-ping order stable between runs (spec).
    return byValue != 0 ? byValue : a.key.title.compareTo(b.key.title);
  });

  return [...measured.map((e) => e.key), ...untested, ...dead];
}
