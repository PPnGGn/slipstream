import 'package:flutter/material.dart';
import 'package:slipstream/core/service/vpn_service/vpn_service_cubit.dart';

bool isTunnelActive(VpnState state) => state.maybeWhen(
  connected: (_, _, _, _) => true,
  connecting: () => true,
  orElse: () => false,
);

void notifyIfTunnelActive(BuildContext context, VpnServiceCubit vpn) {
  if (!isTunnelActive(vpn.state)) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      const SnackBar(content: Text('Применится при переподключении')),
    );
}
