import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:slipstream/app/app_assets.dart';
import 'package:slipstream/app/di/injector.dart';
import 'package:slipstream/core/formatters.dart';
import 'package:slipstream/core/models/vpn_server/vpn_server.dart';
import 'package:slipstream/core/service/vpn_service/vpn_service_cubit.dart';
import 'package:slipstream/core/theme/app_colors.dart';
import 'package:slipstream/core/theme/app_theme.dart';
import 'package:slipstream/features/subscriptions/cubit/subscriptions_cubit.dart';
import 'package:slipstream/features/vpn/ui/widgets/connection_timer.dart';

class _ConnectionStatus {
  const _ConnectionStatus({required this.color, required this.label});

  final Color color;
  final String label;

  factory _ConnectionStatus.fromState(VpnState state, AppColors colors) {
    return state.when(
      disconnected: () =>
          _ConnectionStatus(color: colors.textMuted, label: 'Not connected'),
      connecting: () =>
          _ConnectionStatus(color: colors.warn, label: 'Connecting…'),
      connected: (_, _, _, _) =>
          _ConnectionStatus(color: colors.ok, label: 'Connected'),
      disconnecting: () =>
          _ConnectionStatus(color: colors.warn, label: 'Disconnecting…'),
      error: (_) => _ConnectionStatus(color: colors.danger, label: 'Error'),
    );
  }
}

class ConnectionCard extends StatelessWidget {
  const ConnectionCard({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = getIt<AppColors>();
    final cubit = getIt<VpnServiceCubit>();

    return BlocBuilder<VpnServiceCubit, VpnState>(
      bloc: cubit,
      builder: (context, state) {
        final selectedServer = getIt<SubscriptionsCubit>().state.selectedServer;
        final active = state.maybeWhen(
          connected: (_, _, _, _) => true,
          orElse: () => false,
        );
        final busy = state.maybeWhen(
          connecting: () => true,
          disconnecting: () => true,
          orElse: () => false,
        );

        return Container(
          padding: const .all(18),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: .circular(AppDims.radiusCard),
            border: .all(color: colors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              _PowerButton(
                active: active,
                busy: busy,
                onTap: () => cubit.toggle(selectedServer),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _Status(state: state, selectedServer: selectedServer),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PowerButton extends StatefulWidget {
  const _PowerButton({
    required this.active,
    required this.busy,
    required this.onTap,
  });

  final bool active;
  final bool busy;
  final VoidCallback onTap;

  @override
  State<_PowerButton> createState() => _PowerButtonState();
}

class _PowerButtonState extends State<_PowerButton>
    with SingleTickerProviderStateMixin {
  static const _size = 96.0;

  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void initState() {
    super.initState();
    if (widget.busy) _spin.repeat();
  }

  @override
  void didUpdateWidget(_PowerButton old) {
    super.didUpdateWidget(old);
    if (widget.busy && !_spin.isAnimating) {
      _spin.repeat();
    } else if (!widget.busy && _spin.isAnimating) {
      _spin
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = getIt<AppColors>();
    final iconColor = widget.active
        ? colors.ok
        : widget.busy
        ? colors.textSecondary
        : colors.textMuted;

    return GestureDetector(
      onTap: widget.onTap,
      behavior: .opaque,
      child: SizedBox(
        width: _size,
        height: _size,
        child: Stack(
          alignment: .center,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                shape: .circle,
                border: .all(color: colors.border, width: 2),
                boxShadow: widget.active
                    ? [
                        BoxShadow(
                          color: colors.ok.withValues(alpha: 0.45),
                          blurRadius: 18,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: const SizedBox.square(dimension: _size),
            ),
            if (widget.busy)
              RotationTransition(
                turns: _spin,
                child: CustomPaint(
                  size: const Size.square(_size),
                  painter: _ArcPainter(colors.ringGradient),
                ),
              ),
            Container(
              width: _size - 18,
              height: _size - 18,
              decoration: BoxDecoration(
                shape: .circle,
                border: .all(color: colors.border),
                gradient: LinearGradient(
                  begin: .topCenter,
                  end: .bottomCenter,
                  colors: [colors.surfaceRaised, colors.surface],
                ),
              ),
              child: Center(
                child: SvgPicture.asset(
                  AppAssets.power,
                  width: 28,
                  height: 28,
                  colorFilter: .mode(iconColor, .srcIn),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  _ArcPainter(this.gradient);

  final List<Color> gradient;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = .stroke
      ..strokeWidth = 3
      ..strokeCap = .round
      ..shader = SweepGradient(
        colors: [gradient.first.withValues(alpha: 0), ...gradient],
        stops: const [0, 0.35, 0.7, 1],
      ).createShader(rect);
    canvas.drawArc(
      rect.deflate(1.5),
      -math.pi / 2,
      math.pi * 1.5,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.gradient != gradient;
}

class _Status extends StatelessWidget {
  const _Status({required this.state, required this.selectedServer});

  final VpnState state;
  final VpnServer? selectedServer;

  @override
  Widget build(BuildContext context) {
    final colors = getIt<AppColors>();
    final textTheme = Theme.of(context).textTheme;

    final status = _ConnectionStatus.fromState(state, colors);

    final server =
        state.whenOrNull(connected: (s, _, _, _) => s) ?? selectedServer;
    final subtitle =
        state.whenOrNull(error: (message) => message) ??
        server?.title ??
        'Add a subscription to get started';

    return Column(
      crossAxisAlignment: .start,
      mainAxisSize: .min,
      children: [
        Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(shape: .circle, color: status.color),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                status.label,
                style: textTheme.titleSmall?.copyWith(color: status.color),
                overflow: .ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: textTheme.labelSmall,
          maxLines: 1,
          overflow: .ellipsis,
        ),
        state.maybeWhen(
          connected: (_, connectedAt, _, _) => Padding(
            padding: const .only(top: 6),
            child: ConnectionTimer(
              connectedAt: connectedAt,
              style: textTheme.titleMedium?.copyWith(
                fontFamily: 'monospace',
                fontFeatures: const [FontFeature.tabularFigures()],
                letterSpacing: 0.5,
              ),
            ),
          ),
          orElse: () => const SizedBox.shrink(),
        ),
        const SizedBox(height: 9),
        _Chips(state: state, selectedServer: selectedServer),
      ],
    );
  }
}

class _Chips extends StatelessWidget {
  const _Chips({required this.state, required this.selectedServer});

  final VpnState state;
  final VpnServer? selectedServer;

  @override
  Widget build(BuildContext context) {
    final traffic = state.whenOrNull(
      connected: (_, _, up, down) =>
          '↑ ${formatBytes(up)}   ↓ ${formatBytes(down)}',
    );

    final chips = <Widget>[
      if (selectedServer != null)
        _Chip(_protocolOf(selectedServer!.configJson)),
      if (traffic != null) _Chip(traffic),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();

    return Wrap(spacing: 6, runSpacing: 6, children: chips);
  }

  static String _protocolOf(String configJson) {
    final match = RegExp(
      r'"protocol"\s*:\s*"(vless|vmess|shadowsocks|trojan)"',
    ).firstMatch(configJson);
    return match?.group(1)?.toUpperCase() ?? 'PROXY';
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = getIt<AppColors>();
    return Container(
      padding: const .symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: colors.chip,
        borderRadius: .circular(100),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'monospace',
          fontFeatures: const [FontFeature.tabularFigures()],
          fontSize: 10,
          fontWeight: .w600,
          color: colors.textSecondary,
        ),
      ),
    );
  }
}
