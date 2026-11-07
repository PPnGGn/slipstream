import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:slipstream/core/service/vpn_service/vpn_service_cubit.dart';
import 'package:slipstream/features/dns/cubit/dns_cubit.dart';
import 'package:slipstream/features/geo/cubit/geo_cubit.dart';
import 'package:slipstream/features/launch_sync/data/launch_sync.dart';
import 'package:slipstream/features/launch_sync/data/launch_sync_decision.dart';
import 'package:slipstream/features/routing/cubit/ad_block_cubit.dart';
import 'package:slipstream/features/routing/cubit/custom_rules_cubit.dart';
import 'package:slipstream/features/routing/cubit/lan_bypass_cubit.dart';
import 'package:slipstream/features/routing/cubit/ru_bypass_cubit.dart';
import 'package:slipstream/features/security/cubit/ipv6_cubit.dart';
import 'package:slipstream/features/security/cubit/kill_switch_cubit.dart';
import 'package:slipstream/features/split_tunnel/cubit/split_tunnel_cubit.dart';
import 'package:slipstream/features/subscriptions/cubit/subscriptions_cubit.dart';
import 'package:slipstream/features/vpn/data/vpn_repository.dart';
import 'package:talker_flutter/talker_flutter.dart';

/// Wires [LaunchSync] to the app: every setting that shapes the config of a
/// start, the selected server, and the moment the VPN goes idle are a change,
/// and a first pass runs once the app knows its state. Android only (the saved
/// launch is the tile's).
///
/// The first pass waits for the same two things auto-connect does, for the same
/// reasons: the subscriptions (an empty list before they load means "not known
/// yet") and the first read of the native VPN status (a tunnel the tile already
/// started would look idle, and its launch must not be touched).
@lazySingleton
class LaunchSyncRunner {
  LaunchSyncRunner(
    this._subscriptions,
    this._vpn,
    this._repository,
    this._ruBypass,
    this._adBlock,
    this._lanBypass,
    this._customRules,
    this._dns,
    this._ipv6,
    this._killSwitch,
    this._splitTunnel,
    this._geo,
    this._talker,
  );

  static const _waitLimit = Duration(seconds: 10);

  final SubscriptionsCubit _subscriptions;
  final VpnServiceCubit _vpn;
  final VpnRepository _repository;
  final RuBypassCubit _ruBypass;
  final AdBlockCubit _adBlock;
  final LanBypassCubit _lanBypass;
  final CustomRulesCubit _customRules;
  final DnsCubit _dns;
  final Ipv6Cubit _ipv6;
  final KillSwitchCubit _killSwitch;
  final SplitTunnelCubit _splitTunnel;
  final GeoCubit _geo;
  final Talker _talker;

  var _started = false;

  Future<void> init() async {
    if (_started) return;
    _started = true;
    if (!isLaunchSyncSupported(defaultTargetPlatform)) return;

    final changes = StreamController<void>.broadcast();
    // Not `_subscriptions.stream` as it is: it moves for many reasons (a ping,
    // a refresh in progress). Only the selected server, with its config,
    // matters here; VpnServer compares by value, so distinct() drops the rest.
    final sources = <Stream<Object?>>[
      _subscriptions.stream.map((state) => state.selectedServer).distinct(),
      _ruBypass.stream,
      _adBlock.stream,
      _lanBypass.stream,
      _customRules.stream,
      _dns.stream,
      _ipv6.stream,
      _killSwitch.stream,
      _splitTunnel.stream,
      // Which geo tokens the config keeps depends on what is installed.
      _geo.stream,
      // A change made during a session could not be saved then; the moment the
      // session ends is the first one that can.
      _vpn.stream.map(isLaunchSavable).distinct().where((idle) => idle),
    ];
    for (final source in sources) {
      source.listen((_) => changes.add(null));
    }

    final sync = LaunchSync(
      changes: changes.stream,
      vpnState: () => _vpn.state,
      selectedServer: () => _subscriptions.state.selectedServer,
      build: _repository.buildConfigMessage,
      save: _repository.saveLaunch,
      onError: (e, st) => _talker.handle(e, st, 'Saving the launch failed'),
    )..start();

    try {
      if (!_subscriptions.state.isLoaded) {
        await _subscriptions.stream
            .firstWhere((state) => state.isLoaded)
            .timeout(_waitLimit);
      }
      await _vpn.firstSync.timeout(_waitLimit);
      await sync.syncNow();
    } on TimeoutException {
      _talker.warning('Launch sync: gave up waiting, first pass skipped');
    } catch (e, st) {
      _talker.handle(e, st, 'Launch sync failed');
    }
  }
}
