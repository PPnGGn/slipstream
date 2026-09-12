import 'dart:async';
import 'package:injectable/injectable.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:slipstream/core/service/vpn_service/vpn_service_cubit.dart';
import 'package:slipstream/features/geo/cubit/geo_cubit.dart';

/// Decides *when* the geo databases get fetched. The app never polls:
///
///  - **First install:** geo can't be downloaded before the first working
///    connection (in Russia, GitHub may be unreachable without the VPN). So if
///    nothing is installed, wait for the first `connected` and pull it then —
///    the config was gated to strip geo, nothing holds the files.
///  - **Updates:** only when the user taps "Обновить" on the geo settings page.
///    [updateNow] checks the latest release and downloads it only if it's newer
///    than what's installed.
@lazySingleton
class GeoUpdateService {
  GeoUpdateService(this._geo, this._vpn, this._talker);

  final GeoCubit _geo;
  final VpnServiceCubit _vpn;
  final Talker _talker;

  StreamSubscription<VpnState>? _vpnSub;
  bool _bootstrapTriggered = false;

  void init() {
    _vpnSub ??= _vpn.stream.listen(_onVpnState);
  }

  /// "Download" button — nothing installed yet.
  Future<void> downloadNow() => _geo.downloadLatest();

  /// "Update" button — check the latest release and install it only if it's
  /// newer than what's on disk.
  Future<GeoUpdateOutcome> updateNow() => _geo.updateIfNewer();

  void _onVpnState(VpnState state) {
    final connected = state.maybeWhen(
      connected: (_, _, _, _) => true,
      orElse: () => false,
    );
    if (connected && !_bootstrapTriggered && _geo.state is GeoAbsent) {
      _bootstrapTriggered = true;
      _talker.info('Geo: first connection up, fetching geo databases');
      unawaited(_geo.downloadLatest());
    }
  }

  @disposeMethod
  void dispose() => _vpnSub?.cancel();
}
