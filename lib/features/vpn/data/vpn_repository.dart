import 'dart:async';
import 'package:injectable/injectable.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:slipstream/core/models/vpn_server/vpn_server.dart';
import 'package:slipstream/core/models/result.dart';
import 'package:slipstream/features/vpn/data/vpn_api.g.dart';
import 'package:slipstream/features/vpn/data/vpn_event_receiver.dart';
import 'package:slipstream/features/vpn/data/xray_log_store.dart';

@lazySingleton
class VpnRepository {
  final Talker _talker;
  final VpnConnection _vpnConnection;
  final NativeVpnEventReceiver _events;
  final XrayLogStore _xrayLogStore;
  late final StreamSubscription<VpnLogMessage> _logSubscription;

  VpnRepository(
    this._talker,
    this._vpnConnection,
    this._events,
    this._xrayLogStore,
  ) {
    _logSubscription = _events.logs.listen(_xrayLogStore.add);
  }

  Stream<VpnStatusMessage> get status => _events.status;
  Stream<VpnTrafficMessage> get traffic => _events.traffic;

  Future<VpnStatusMessage> getStatus() => _vpnConnection.getStatus();

  Future<Result<void>> start(VpnServer server) async {
    try {
      _talker.debug('Starting VPN with server: ${server.title}');
      final result = await _vpnConnection.start(
        VpnConfigMessage(
          configJson: server.configJson,
          serverId: server.id,
          title: server.title,
        ),
      );

      if (result.successful) {
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
