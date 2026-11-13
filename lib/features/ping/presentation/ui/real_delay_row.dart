import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:slipstream/app/di/injector.dart';
import 'package:slipstream/core/models/vpn_server/vpn_server.dart';
import 'package:slipstream/core/theme/app_colors.dart';
import 'package:slipstream/features/ping/presentation/real_delay_cubit.dart';
import 'package:slipstream/features/ping/presentation/real_delay_entry.dart';
import 'package:slipstream/features/ping/presentation/ui/real_delay_labels.dart';
import 'package:slipstream/features/subscriptions/data/server_problem.dart';
import 'package:slipstream/l10n/l10n_context.dart';

/// The "Real delay" row of the server sheet: what it is, the last result and
/// the button. It only draws what [RealDelayCubit] holds and passes the tap on.
/// A server that cannot work (see serverProblem) has no row: there is nothing
/// to check.
class RealDelayRow extends StatelessWidget {
  const RealDelayRow({super.key, required this.server});

  final VpnServer server;

  @override
  Widget build(BuildContext context) {
    if (serverProblem(server) != null) return const SizedBox.shrink();

    final cubit = getIt<RealDelayCubit>();
    final colors = AppColors.of(context);
    final l10n = context.l10n;

    return BlocBuilder<RealDelayCubit, RealDelayState>(
      bloc: cubit,
      builder: (context, state) {
        final entry = state.of(server.id);
        final result = realDelayResultText(l10n, entry);
        // Another server's check holds the button too: one at a time.
        final canTap = !state.busy;

        return Container(
          margin: const .only(top: 14),
          padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 10, 10),
          decoration: BoxDecoration(
            color: colors.chip,
            borderRadius: .circular(14),
          ),
          child: Row(
            spacing: 10,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: .start,
                  spacing: 2,
                  children: [
                    // A Wrap: with large text the result goes under the title
                    // instead of pushing past the edge of the row.
                    Wrap(
                      spacing: 8,
                      crossAxisAlignment: .center,
                      children: [
                        Text(
                          l10n.serverInfoRealDelayTitle,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: .w700,
                            color: colors.textPrimary,
                          ),
                        ),
                        if (result != null)
                          Text(
                            result,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11.5,
                              fontWeight: .w700,
                              color: _resultColor(colors, entry),
                            ),
                          ),
                      ],
                    ),
                    Text(
                      l10n.serverInfoRealDelayHint,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.35,
                        color: colors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              // At most two fifths of the row: in a long language with large
              // text the label wraps instead of squeezing the description.
              Flexible(
                flex: 2,
                child: _CheckButton(
                  colors: colors,
                  label: realDelayButtonText(l10n, entry),
                  onTap: canTap ? () => cubit.measure(server) : null,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static Color _resultColor(AppColors colors, RealDelayEntry entry) {
    final latency = entry.latencyMs;
    if (latency == null) return colors.danger;
    return switch (realDelayTierOf(latency)) {
      RealDelayTier.good => colors.ok,
      RealDelayTier.medium => colors.warn,
      RealDelayTier.poor => colors.danger,
    };
  }
}

/// Small bordered button, the same kind as the geo row's refresh chip. Own
/// widget rather than an OutlinedButton: the app theme gives those the full
/// width of a form, which is not what a chip in a row wants. A null [onTap]
/// is the disabled look.
class _CheckButton extends StatelessWidget {
  const _CheckButton({
    required this.colors,
    required this.label,
    required this.onTap,
  });

  final AppColors colors;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      child: GestureDetector(
        onTap: onTap,
        behavior: .opaque,
        child: Opacity(
          opacity: onTap == null ? 0.5 : 1,
          child: Container(
            constraints: const BoxConstraints(minHeight: 32),
            padding: const .symmetric(horizontal: 13, vertical: 6),
            alignment: .center,
            decoration: BoxDecoration(
              borderRadius: .circular(10),
              border: .all(color: colors.border),
            ),
            child: Text(
              label,
              textAlign: .center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: .w600,
                color: colors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
