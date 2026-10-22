import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:slipstream/app/app_assets.dart';
import 'package:slipstream/app/di/injector.dart';
import 'package:slipstream/core/service/vpn_service/vpn_service_cubit.dart';
import 'package:slipstream/core/theme/app_colors.dart';
import 'package:slipstream/core/theme/cubit/theme_cubit.dart';
import 'package:slipstream/core/utils/formatters.dart';
import 'package:slipstream/features/subscriptions/cubit/subscriptions_cubit.dart';
import 'package:slipstream/features/subscriptions/data/vpn_server_display.dart';
import 'package:slipstream/features/vpn/presentation/connection_status_view.dart';
import 'package:slipstream/features/vpn/ui/widgets/connection_phase_colors.dart';
import 'package:slipstream/features/vpn/ui/widgets/connection_timer.dart';

/// Compact home layout: a slim bar at the bottom with a connect switch,
/// the server and live traffic. Same state as the classic card — only the
/// look differs.
class CompactConnectionBar extends StatelessWidget {
  const CompactConnectionBar({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppThemeCubit, AppThemeState>(
      bloc: getIt<AppThemeCubit>(),
      builder: (context, _) {
        final colors = getIt<AppColors>();
        final cubit = getIt<VpnServiceCubit>();

        return BlocBuilder<VpnServiceCubit, VpnState>(
          bloc: cubit,
          builder: (context, state) {
            return BlocBuilder<SubscriptionsCubit, SubscriptionsState>(
              bloc: getIt<SubscriptionsCubit>(),
              builder: (context, subsState) {
                final selectedServer = subsState.selectedServer;
                final view = ConnectionStatusView.from(
                  state: state,
                  hasSubscriptions: subsState.subscriptions.isNotEmpty,
                  selectedServer: selectedServer,
                );
                final borderColor = switch (view.phase) {
                  ConnectionPhase.on => colors.connectedLine,
                  ConnectionPhase.busy => colors.warn.withValues(alpha: 0.45),
                  ConnectionPhase.error => colors.danger.withValues(
                    alpha: 0.45,
                  ),
                  ConnectionPhase.off => colors.border,
                };

                return SafeArea(
                  top: false,
                  child: Padding(
                    padding: const .fromLTRB(16, 8, 16, 20),
                    // The whole bar toggles the tunnel, like the classic
                    // card; the switch only shows the state.
                    child: GestureDetector(
                      onTap: () => cubit.toggle(selectedServer),
                      behavior: .opaque,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const .symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: .circular(20),
                          border: .all(color: borderColor),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x1F141420),
                              blurRadius: 24,
                              offset: Offset(0, -6),
                            ),
                          ],
                        ),
                        child: Row(
                          spacing: 14,
                          children: [
                            _ConnectSwitch(colors: colors, phase: view.phase),
                            Expanded(
                              child: _Details(
                                colors: colors,
                                state: state,
                                view: view,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

/// 76×40 track; the knob with the power icon slides right while the
/// tunnel is up or changing. Display only: taps go to the whole bar.
class _ConnectSwitch extends StatelessWidget {
  const _ConnectSwitch({required this.colors, required this.phase});

  final AppColors colors;
  final ConnectionPhase phase;

  @override
  Widget build(BuildContext context) {
    final on = phase == ConnectionPhase.on;
    final busy = phase == ConnectionPhase.busy;
    const duration = Duration(milliseconds: 300);
    const curve = Cubic(0.2, 0.9, 0.3, 1);

    return AnimatedContainer(
      duration: duration,
      width: 76,
      height: 40,
      padding: const .all(4),
      decoration: BoxDecoration(
        color: on
            ? colors.connectedFill
            : busy
            ? colors.warn.withValues(alpha: 0.24)
            : colors.chip,
        borderRadius: .circular(100),
        border: .all(color: colors.border),
      ),
      child: AnimatedAlign(
        duration: duration,
        curve: curve,
        alignment: on || busy ? .centerRight : .centerLeft,
        child: AnimatedContainer(
          duration: duration,
          width: 32,
          height: 32,
          alignment: .center,
          decoration: BoxDecoration(
            shape: .circle,
            color: on
                ? colors.ok
                : busy
                ? colors.warn
                : colors.segment,
            boxShadow: const [
              BoxShadow(
                color: Color(0x4D141420),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: SvgPicture.asset(
            AppAssets.power,
            width: 16,
            height: 16,
            colorFilter: .mode(
              on || busy ? const Color(0xFF22222E) : colors.textSecondary,
              .srcIn,
            ),
          ),
        ),
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({
    required this.colors,
    required this.state,
    required this.view,
  });

  final AppColors colors;
  final VpnState state;
  final ConnectionStatusView view;

  @override
  Widget build(BuildContext context) {
    final server = view.server;
    final traffic = state.whenOrNull(connected: (_, _, up, down) => (up, down));
    final connectedAt = state.whenOrNull(connected: (_, at, _, _) => at);
    final statusColor = view.phase.accent(colors) ?? colors.textPrimary;
    final mono = TextStyle(
      fontFamily: 'monospace',
      fontFeatures: const [FontFeature.tabularFigures()],
      fontSize: 10.5,
      fontWeight: .w600,
      color: colors.textSecondary,
    );
    final arrow = TextStyle(color: colors.primary);

    return Column(
      crossAxisAlignment: .start,
      mainAxisSize: .min,
      children: [
        Row(
          spacing: 7,
          children: [
            if (server != null)
              Text(
                server.flagEmoji,
                style: const TextStyle(fontSize: 16, height: 1),
              ),
            Expanded(
              child: Text(
                server?.displayTitle ?? 'No server selected',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: .w700,
                  color: colors.textPrimary,
                ),
                maxLines: 1,
                overflow: .ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        // The status takes its width first; on a narrow screen the traffic
        // gets cut with an ellipsis, never the timer.
        Row(
          spacing: 12,
          children: [
            Flexible(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: '↑', style: arrow),
                    TextSpan(text: ' ${formatBytesFixed(traffic?.$1 ?? 0)}'),
                  ],
                ),
                style: mono,
                maxLines: 1,
                overflow: .ellipsis,
              ),
            ),
            Flexible(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: '↓', style: arrow),
                    TextSpan(text: ' ${formatBytesFixed(traffic?.$2 ?? 0)}'),
                  ],
                ),
                style: mono,
                maxLines: 1,
                overflow: .ellipsis,
              ),
            ),
            if (connectedAt != null)
              ConnectionTimer(
                connectedAt: connectedAt,
                style: mono.copyWith(color: statusColor),
              )
            else
              Text(
                view.compactLabel ?? '',
                style: mono.copyWith(color: statusColor),
                maxLines: 1,
              ),
          ],
        ),
      ],
    );
  }
}
