import 'package:flutter/material.dart';
import 'package:slipstream/app/theme.dart';
import 'package:slipstream/core/formatters.dart';
import 'package:slipstream/core/models/vpn_server/vpn_server.dart';
import 'package:slipstream/features/vpn/cubit/vpn_cubit.dart';
import 'package:slipstream/features/vpn/ui/widgets/connect_button.dart';
import 'package:slipstream/features/vpn/ui/widgets/connection_timer.dart';

/// The connect button plus the status/timer/traffic readout beneath it.
class ConnectionArea extends StatelessWidget {
  const ConnectionArea({
    super.key,
    required this.vpnState,
    required this.selectedServer,
    required this.hasSubscriptions,
    required this.onConnect,
    required this.onDisconnect,
  });

  final VpnState vpnState;
  final VpnServer? selectedServer;
  final bool hasSubscriptions;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;

  ConnectButtonStatus get _buttonStatus => vpnState.when(
    disconnected: () => ConnectButtonStatus.idle,
    connecting: () => ConnectButtonStatus.busy,
    connected: (_, _, _, _) => ConnectButtonStatus.connected,
    disconnecting: () => ConnectButtonStatus.busy,
    error: (_) => ConnectButtonStatus.error,
  );

  @override
  Widget build(BuildContext context) {
    final isConnected = vpnState.maybeWhen(
      connected: (_, _, _, _) => true,
      orElse: () => false,
    );
    final isBusy = vpnState.maybeWhen(
      connecting: () => true,
      disconnecting: () => true,
      orElse: () => false,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      child: Column(
        children: [
          ConnectButton(
            status: _buttonStatus,
            enabled: isConnected || (!isBusy && selectedServer != null),
            onTap: isConnected ? onDisconnect : onConnect,
          ),
          const SizedBox(height: 28),
          vpnState.when(
            disconnected: () => _statusRow(
              icon: hasSubscriptions
                  ? Icons.touch_app_outlined
                  : Icons.add_circle_outline,
              color: AppColors.textSecondary,
              text: !hasSubscriptions
                  ? 'Добавьте подписку сверху'
                  : selectedServer == null
                  ? 'Выберите сервер ниже'
                  : 'Нажмите, чтобы подключиться',
            ),
            connecting: () => _statusRow(
              icon: Icons.sync_rounded,
              color: AppColors.amberBusy,
              text: 'Подключение…',
            ),
            connected: (server, connectedAt, up, down) =>
                _connected(server, connectedAt, up, down),
            disconnecting: () => _statusRow(
              icon: Icons.sync_rounded,
              color: AppColors.amberBusy,
              text: 'Отключение…',
            ),
            error: (message) => _statusRow(
              icon: Icons.error_outline_rounded,
              color: AppColors.redFF6A55,
              text: message,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusRow({
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _connected(VpnServer server, DateTime connectedAt, int up, int down) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.check_circle_rounded,
              size: 18,
              color: AppColors.green19FF90,
            ),
            const SizedBox(width: 8),
            const Text(
              'Подключено',
              style: TextStyle(
                color: AppColors.green19FF90,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          server.title,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.grayA9BAC6,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        ConnectionTimer(
          connectedAt: connectedAt,
          style: const TextStyle(
            color: AppColors.blue48FDFF,
            fontSize: 22,
            fontWeight: FontWeight.w600,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _trafficChip(Icons.arrow_upward_rounded, formatBytes(up)),
            const SizedBox(width: 20),
            _trafficChip(Icons.arrow_downward_rounded, formatBytes(down)),
          ],
        ),
      ],
    );
  }

  Widget _trafficChip(IconData icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AppColors.grayA9BAC6),
        const SizedBox(width: 4),
        Text(value, style: const TextStyle(color: AppColors.grayA9BAC6)),
      ],
    );
  }
}
