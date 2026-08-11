import 'dart:async';
import 'package:slipstream/features/vpn/data/vpn_api.g.dart';

class NativeVpnEventReceiver implements VpnEventReceiver {
  final _status = StreamController<VpnStatusMessage>.broadcast();
  final _logs = StreamController<VpnLogMessage>.broadcast();
  final _traffic = StreamController<VpnTrafficMessage>.broadcast();

  Stream<VpnStatusMessage> get status => _status.stream;
  Stream<VpnLogMessage> get logs => _logs.stream;
  Stream<VpnTrafficMessage> get traffic => _traffic.stream;

  void register() => VpnEventReceiver.setUp(this);

  @override
  void onStatusChanged(VpnStatusMessage message) => _status.add(message);

  @override
  void onLog(VpnLogMessage message) => _logs.add(message);

  @override
  void onTraffic(VpnTrafficMessage message) => _traffic.add(message);
}
