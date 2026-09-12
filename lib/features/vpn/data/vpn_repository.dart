import 'dart:async';
import 'package:injectable/injectable.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:slipstream/core/models/vpn_server/vpn_server.dart';
import 'package:slipstream/core/models/result.dart';
import 'package:slipstream/features/geo/cubit/geo_cubit.dart';
import 'package:slipstream/features/geo/data/geo_config_gate.dart';
import 'package:slipstream/features/geo/data/geo_paths.dart';
import 'package:slipstream/features/routing/cubit/ad_block_cubit.dart';
import 'package:slipstream/features/routing/cubit/ru_bypass_cubit.dart';
import 'package:slipstream/features/routing/data/local_proxy_gate.dart';
import 'package:slipstream/features/routing/data/routing_policy_gate.dart';
import 'package:slipstream/features/vpn/data/vpn_api.g.dart';
import 'package:slipstream/features/vpn/data/vpn_event_receiver.dart';
import 'package:slipstream/features/vpn/data/xray_log_store.dart';

@lazySingleton
class VpnRepository {
  final Talker _talker;
  final VpnConnection _vpnConnection;
  final NativeVpnEventReceiver _events;
  final XrayLogStore _xrayLogStore;
  final GeoConfigGate _geoGate;
  final GeoCubit _geoCubit;
  final GeoPaths _geoPaths;
  final LocalProxyGate _localProxyGate;
  final LocalProxyPort _localProxyPort;
  final RoutingPolicyGate _routingPolicyGate;
  final RuBypassCubit _ruBypassCubit;
  final AdBlockCubit _adBlockCubit;
  late final StreamSubscription<VpnLogMessage> _logSubscription;

  VpnRepository(
    this._talker,
    this._vpnConnection,
    this._events,
    this._xrayLogStore,
    this._geoGate,
    this._geoCubit,
    this._geoPaths,
    this._localProxyGate,
    this._localProxyPort,
    this._routingPolicyGate,
    this._ruBypassCubit,
    this._adBlockCubit,
  ) {
    _logSubscription = _events.logs.listen(_xrayLogStore.add);
  }

  Stream<VpnStatusMessage> get status => _events.status;
  Stream<VpnTrafficMessage> get traffic => _events.traffic;

  Future<VpnStatusMessage> getStatus() => _vpnConnection.getStatus();

  Future<Result<void>> start(VpnServer server) async {
    _localProxyPort.value =
        null; // set below only once the core confirms it's up
    try {
      _talker.debug('Starting VPN with server: ${server.title}');
      final geoDir = await _geoPaths.dir();

      // 1. guarantee a loopback http inbound and learn its port, before any
      //    gate touches the config (the gates only rewrite routing/dns).
      final (withInbound, proxyPort) = _localProxyGate.ensureHttpInbound(
        server.configJson,
      );
      // 2. client's own split policy (RU-bypass, ad-block), for scaffold
      //    configs that carry no routing of their own.
      final withPolicy = _routingPolicyGate.apply(
        withInbound,
        split: _ruBypassCubit.state,
        adBlock: _adBlockCubit.state,
      );
      // 3. strip geo tokens the installed .dat can't resolve.
      final configJson = _geoGate.prepare(withPolicy, _geoCubit.state);
      final result = await _vpnConnection.start(
        VpnConfigMessage(
          configJson: configJson,
          serverId: server.id,
          title: server.title,
          geoAssetDir: geoDir,
        ),
      );

      if (result.successful) {
        _localProxyPort.value = proxyPort;
        _talker.info('Xray core started successfully');
        return const Success(null);
      }
      final errorMsg = result.error ?? 'Unknown Xray core error';
      _talker.error('Error on the Kotlin side: $errorMsg');
      return Failure(errorMsg);
    } catch (e, st) {
      _talker.handle(e, st, 'Bridge crashed on start');
      return Failure('System failure: ${e.toString()}', e);
    }
  }

  Future<Result<void>> stop() async {
    _localProxyPort.value = null;
    try {
      _talker.debug('Stopping VPN...');
      final result = await _vpnConnection.stop();

      if (result.successful) {
        _talker.info('Xray core stopped');
        return const Success(null);
      }
      final errorMsg = result.error ?? 'Unknown stop error';
      _talker.error('Stop error: $errorMsg');
      return Failure(errorMsg);
    } catch (e, st) {
      _talker.handle(e, st, 'Bridge crashed on stop');
      return Failure('System failure: ${e.toString()}', e);
    }
  }

  @disposeMethod
  void dispose() => _logSubscription.cancel();
}
