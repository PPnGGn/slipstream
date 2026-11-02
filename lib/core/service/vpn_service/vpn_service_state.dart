part of 'vpn_service_cubit.dart';

@freezed
abstract class VpnState with _$VpnState {
  const factory VpnState.disconnected() = _Disconnected;
  const factory VpnState.connecting() = _Connecting;
  const factory VpnState.connected(
    VpnServer server, {
    required DateTime connectedAt,
    @Default(0) int uplinkBytes,
    @Default(0) int downlinkBytes,
  }) = _Connected;
  const factory VpnState.disconnecting() = _Disconnecting;
  const factory VpnState.error(String message) = _Error;

  /// The kill switch holds the traffic after the tunnel failed: no VPN and no
  /// internet until the user reconnects or turns the VPN off.
  const factory VpnState.blocked(String message) = _Blocked;
}
