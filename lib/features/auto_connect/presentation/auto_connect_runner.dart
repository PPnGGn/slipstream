import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:slipstream/core/service/vpn_service/vpn_service_cubit.dart';
import 'package:slipstream/features/auto_connect/cubit/auto_connect_cubit.dart';
import 'package:slipstream/features/auto_connect/data/auto_connect_support.dart';
import 'package:slipstream/features/auto_connect/presentation/auto_connect_decision.dart';
import 'package:slipstream/features/subscriptions/cubit/subscriptions_cubit.dart';
import 'package:slipstream/features/vpn/data/vpn_repository.dart';
import 'package:talker_flutter/talker_flutter.dart';

/// Connects to the selected server when the app opens, if the user asked for it.
///
/// Once per process: coming back to a running app never connects. The two
/// things it waits for are what make the decision safe: the subscriptions
/// (an empty list before they load means "not known yet") and the first read of
/// the native VPN status (otherwise a tunnel the tile already started would
/// look like "disconnected" and get a second start on top of it). What it does
/// with them is in [autoConnectServer].
@lazySingleton
class AutoConnectRunner {
  AutoConnectRunner(
    this._settings,
    this._subscriptions,
    this._vpn,
    this._repository,
    this._talker,
  );

  /// Waiting longer than this for either means something is wrong; connecting
  /// on a guess would be worse than not connecting.
  static const _waitLimit = Duration(seconds: 10);

  final AutoConnectCubit _settings;
  final SubscriptionsCubit _subscriptions;
  final VpnServiceCubit _vpn;
  final VpnRepository _repository;
  final Talker _talker;

  var _started = false;

  Future<void> init() async {
    if (_started) return;
    _started = true;
    if (!isAutoConnectSupported(defaultTargetPlatform)) return;
    // The cheap exit first: with the setting off nothing below is worth waiting for.
    if (!_settings.state) return;

    try {
      if (!_subscriptions.state.isLoaded) {
        await _subscriptions.stream
            .firstWhere((state) => state.isLoaded)
            .timeout(_waitLimit);
      }
      await _vpn.firstSync.timeout(_waitLimit);

      // The state is read after the last await: it may have moved meanwhile.
      final permissionGranted = await _repository.vpnPermissionGranted();
      final server = autoConnectServer(
        enabled: _settings.state,
        permissionGranted: permissionGranted,
        vpnState: _vpn.state,
        selectedServer: _subscriptions.state.selectedServer,
      );
      if (server == null) {
        _talker.debug(
          'Auto-connect: skipped (permission=$permissionGranted, '
          'vpn=${_vpn.state.runtimeType})',
        );
        return;
      }
      _talker.info('Auto-connect: connecting to ${server.title}');
      await _vpn.connect(server);
    } on TimeoutException {
      _talker.warning('Auto-connect: gave up waiting, not connecting');
    } catch (e, st) {
      _talker.handle(e, st, 'Auto-connect failed');
    }
  }
}
