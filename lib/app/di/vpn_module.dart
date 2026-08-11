import 'package:injectable/injectable.dart';
import 'package:slipstream/features/vpn/data/vpn_api.g.dart';
import 'package:slipstream/features/vpn/data/vpn_event_receiver.dart';

@module
abstract class VpnModule {
  @lazySingleton
  VpnConnection get vpnConnection => VpnConnection();

  @lazySingleton
  NativeVpnEventReceiver get vpnEventReceiver =>
      NativeVpnEventReceiver()..register();
}
