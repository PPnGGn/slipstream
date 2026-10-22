import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:slipstream/app/app_assets.dart';
import 'package:slipstream/app/di/injector.dart';
import 'package:slipstream/core/utils/formatters.dart';
import 'package:slipstream/core/models/vpn_server/vpn_server.dart';
import 'package:slipstream/core/service/vpn_service/vpn_service_cubit.dart';
import 'package:slipstream/core/theme/app_colors.dart';
import 'package:slipstream/core/theme/cubit/theme_cubit.dart';
import 'package:slipstream/core/theme/protocol_colors.dart';
import 'package:slipstream/features/diagnostics/cubit/memory_monitor_cubit.dart';
import 'package:slipstream/features/diagnostics/cubit/memory_usage_cubit.dart';
import 'package:slipstream/features/diagnostics/data/memory_monitor_mode.dart';
import 'package:slipstream/features/ping/presentation/ping_cubit.dart';
import 'package:slipstream/features/ping/presentation/ping_entry.dart';
import 'package:slipstream/features/subscriptions/cubit/subscriptions_cubit.dart';
import 'package:slipstream/features/subscriptions/data/vpn_server_display.dart';
import 'package:slipstream/features/vpn/presentation/connection_status_view.dart';
import 'package:slipstream/features/vpn/ui/widgets/connection_phase_colors.dart';
import 'package:slipstream/features/vpn/ui/widgets/connection_timer.dart';

/// Classic home layout: the card with the big connect ring.
class ConnectionCard extends StatelessWidget {
  const ConnectionCard({super.key});

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

                return GestureDetector(
                  onTap: () => cubit.toggle(selectedServer),
                  behavior: .opaque,
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    alignment: Alignment.topCenter,
                    child: Container(
                      padding: const .all(18),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: .circular(22),
                        border: .all(color: colors.border),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x14141420),
                            blurRadius: 24,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          _Ring(colors: colors, phase: view.phase),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _Status(
                              colors: colors,
                              state: state,
                              view: view,
                            ),
                          ),
                        ],
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

/// The 96 px connect ring: a pulsing glow while connected, a gradient ring
/// while connected, a spinning arc while busy, a red ring on error.
class _Ring extends StatefulWidget {
  const _Ring({required this.colors, required this.phase});

  final AppColors colors;
  final ConnectionPhase phase;

  @override
  State<_Ring> createState() => _RingState();
}

class _RingState extends State<_Ring> with TickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  // Half of the design's 2.6 s pulse; repeat(reverse) plays the other half.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );

  @override
  void initState() {
    super.initState();
    _syncAnimations();
  }

  @override
  void didUpdateWidget(_Ring old) {
    super.didUpdateWidget(old);
    if (old.phase != widget.phase) _syncAnimations();
  }

  void _syncAnimations() {
    _run(_spin, widget.phase == ConnectionPhase.busy, reverse: false);
    _run(_pulse, widget.phase == ConnectionPhase.on, reverse: true);
  }

  static void _run(
    AnimationController controller,
    bool active, {
    required bool reverse,
  }) {
    if (active && !controller.isAnimating) {
      controller.repeat(reverse: reverse);
    } else if (!active && controller.isAnimating) {
      controller
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final phase = widget.phase;
    final iconColor = phase.accent(colors) ?? colors.textMuted;

    return SizedBox.square(
      dimension: 96,
      child: Stack(
        clipBehavior: .none,
        alignment: .center,
        children: [
          if (phase == ConnectionPhase.on)
            Positioned.fill(
              left: 4,
              top: 4,
              right: 4,
              bottom: 4,
              child: _PulseGlow(animation: _pulse, color: colors.glow),
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              shape: .circle,
              border: .all(color: colors.border, width: 2),
            ),
            child: const SizedBox.square(dimension: 96),
          ),
          if (phase != ConnectionPhase.off)
            Positioned(
              left: -2,
              top: -2,
              width: 100,
              height: 100,
              child: switch (phase) {
                ConnectionPhase.busy => RotationTransition(
                  turns: _spin,
                  child: CustomPaint(
                    painter: _RingPainter(
                      colors: [
                        colors.warn.withValues(alpha: 0),
                        colors.warn.withValues(alpha: 0),
                        colors.warn,
                      ],
                      stops: const [0, 0.12, 1],
                      // CSS conic gradients start at 12 o'clock.
                      startAngle: -math.pi / 2,
                    ),
                  ),
                ),
                ConnectionPhase.on => CustomPaint(
                  painter: _RingPainter(
                    colors: [...colors.ringGradient, colors.ringGradient.first],
                    // Design: conic-gradient(from 210deg …).
                    startAngle: (210 - 90) * math.pi / 180,
                  ),
                ),
                _ => CustomPaint(
                  painter: _RingPainter(colors: [colors.danger, colors.danger]),
                ),
              },
            ),
          Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              shape: .circle,
              border: .all(color: colors.border),
              gradient: LinearGradient(
                // CSS linear-gradient(160deg, …).
                begin: const Alignment(-0.34, -0.94),
                end: const Alignment(0.34, 0.94),
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
    );
  }
}

class _PulseGlow extends StatelessWidget {
  const _PulseGlow({required this.animation, required this.color});

  final Animation<double> animation;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeInOut);
    return AnimatedBuilder(
      animation: curved,
      builder: (context, child) => Opacity(
        opacity: 0.5 + 0.5 * curved.value,
        child: Transform.scale(scale: 1 + 0.05 * curved.value, child: child),
      ),
      child: ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: .circle,
            gradient: RadialGradient(
              colors: [color, color.withValues(alpha: 0)],
              stops: const [0, 0.7],
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.colors, this.stops, this.startAngle = 0});

  final List<Color> colors;
  final List<double>? stops;
  final double startAngle;

  @override
  void paint(Canvas canvas, Size size) {
    const width = 5.5;
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = .stroke
      ..strokeWidth = width
      ..shader = SweepGradient(
        colors: colors,
        stops: stops,
        transform: GradientRotation(startAngle),
      ).createShader(rect);
    canvas.drawCircle(rect.center, size.width / 2 - width / 2, paint);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.startAngle != startAngle ||
      old.stops != stops ||
      !_sameColors(old.colors, colors);

  static bool _sameColors(List<Color> a, List<Color> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

class _Status extends StatelessWidget {
  const _Status({
    required this.colors,
    required this.state,
    required this.view,
  });

  final AppColors colors;
  final VpnState state;
  final ConnectionStatusView view;

  @override
  Widget build(BuildContext context) {
    final accent = view.phase.accent(colors);
    final connectedAt = state.whenOrNull(connected: (_, at, _, _) => at);
    final timerStyle = TextStyle(
      fontFamily: 'monospace',
      fontFeatures: const [FontFeature.tabularFigures()],
      fontSize: 21,
      fontWeight: .w600,
      letterSpacing: 0.4,
      color: colors.textPrimary,
    );

    return Column(
      crossAxisAlignment: .start,
      mainAxisSize: .min,
      children: [
        Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: .circle,
                color: accent ?? colors.textMuted,
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                view.title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: .w700,
                  color: accent ?? colors.textPrimary,
                ),
                maxLines: 1,
                overflow: .ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          view.subtitle,
          style: TextStyle(fontSize: 11.5, color: colors.textMuted),
          maxLines: 1,
          overflow: .ellipsis,
        ),
        // The placeholder keeps the card's height steady across states.
        Padding(
          padding: const .only(top: 6),
          child: connectedAt != null
              ? ConnectionTimer(connectedAt: connectedAt, style: timerStyle)
              : Text(
                  '--:--:--',
                  style: timerStyle.copyWith(color: colors.textMuted),
                ),
        ),
        const SizedBox(height: 9),
        _Chips(colors: colors, state: state, server: view.server),
      ],
    );
  }
}

class _Chips extends StatelessWidget {
  const _Chips({
    required this.colors,
    required this.state,
    required this.server,
  });

  final AppColors colors;
  final VpnState state;
  final VpnServer? server;

  @override
  Widget build(BuildContext context) {
    final traffic = state.whenOrNull(connected: (_, _, up, down) => (up, down));
    final server = this.server;

    return BlocBuilder<MemoryMonitorCubit, MemoryMonitorMode>(
      bloc: getIt<MemoryMonitorCubit>(),
      builder: (context, monitorMode) => Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          if (server == null)
            _Chip(colors: colors, label: 'NO SERVER')
          else
            _ProtocolChip(colors: colors, server: server),
          if (server != null) _PingChip(colors: colors, serverId: server.id),
          _TrafficChip(
            colors: colors,
            up: traffic?.$1 ?? 0,
            down: traffic?.$2 ?? 0,
          ),
          if (monitorMode.enabled) _MemoryChip(colors: colors),
        ],
      ),
    );
  }
}

class _ProtocolChip extends StatelessWidget {
  const _ProtocolChip({required this.colors, required this.server});

  final AppColors colors;
  final VpnServer server;

  @override
  Widget build(BuildContext context) {
    final label = server.meta.tagLabels.first;
    return _Chip(
      colors: colors,
      label: label,
      labelColor: protocolColor(label, colors.palette),
    );
  }
}

/// Ping chip for the selected/connected server (design: the pill
/// between the protocol chip and the traffic chip). Selects its own
/// entry out of the ping cubit so an in-flight run doesn't rebuild
/// the whole connection card on every patch.
class _PingChip extends StatelessWidget {
  const _PingChip({required this.colors, required this.serverId});

  final AppColors colors;
  final String serverId;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<PingCubit, PingViewState, PingEntry>(
      bloc: getIt<PingCubit>(),
      selector: (view) => view.entries[serverId] ?? const PingEntry.notTested(),
      builder: (context, entry) {
        final (label, dotColor) = switch (entry.status) {
          PingRunStatus.measured => (
            '${entry.latencyMs!.round()} ms',
            _qualityColor(colors, entry.latencyMs!),
          ),
          PingRunStatus.dead => ('timeout', colors.danger),
          PingRunStatus.queued ||
          PingRunStatus.measuring => ('··· ms', colors.textMuted),
          PingRunStatus.unsupported => ('n/a', colors.textMuted),
          PingRunStatus.notTested => ('— ms', colors.textMuted),
        };
        return _Chip(colors: colors, label: label, dotColor: dotColor);
      },
    );
  }

  static Color _qualityColor(AppColors colors, double latencyMs) =>
      switch (pingQualityOf(latencyMs)) {
        PingQuality.good => colors.ok,
        PingQuality.medium => colors.warn,
        PingQuality.poor => colors.danger,
      };
}

class _TrafficChip extends StatelessWidget {
  const _TrafficChip({
    required this.colors,
    required this.up,
    required this.down,
  });

  final AppColors colors;
  final int up;
  final int down;

  @override
  Widget build(BuildContext context) {
    final arrow = TextStyle(color: colors.primary);
    return _ChipBox(
      colors: colors,
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '↑', style: arrow),
            TextSpan(text: ' ${formatBytesFixed(up)} '),
            TextSpan(text: '↓', style: arrow),
            TextSpan(text: ' ${formatBytesFixed(down)}'),
          ],
        ),
        style: _chipTextStyle(colors.textSecondary),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.colors,
    required this.label,
    this.dotColor,
    this.labelColor,
  });

  final AppColors colors;
  final String label;
  final Color? dotColor;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    return _ChipBox(
      colors: colors,
      child: Row(
        mainAxisSize: .min,
        children: [
          if (dotColor != null) ...[
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(shape: .circle, color: dotColor),
            ),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: _chipTextStyle(labelColor ?? colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ChipBox extends StatelessWidget {
  const _ChipBox({required this.colors, required this.child});

  final AppColors colors;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const .symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: colors.chip,
        borderRadius: .circular(100),
      ),
      child: child,
    );
  }
}

TextStyle _chipTextStyle(Color color) => TextStyle(
  fontFamily: 'monospace',
  fontFeatures: const [FontFeature.tabularFigures()],
  fontSize: 10,
  fontWeight: .w600,
  color: color,
);

class _MemoryChip extends StatelessWidget {
  const _MemoryChip({required this.colors});

  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MemoryUsageCubit, MemoryUsage>(
      bloc: getIt<MemoryUsageCubit>(),
      builder: (context, usage) {
        final bytes = usage.bytes;
        if (bytes == null) {
          return _Chip(
            colors: colors,
            label: 'RAM — MB',
            dotColor: colors.textMuted,
          );
        }

        final dotColor = switch (usage.health) {
          MemoryHealth.ok => colors.ok,
          MemoryHealth.warn => colors.warn,
          MemoryHealth.danger => colors.danger,
        };
        // The budget only matters on iOS, where it's a real jetsam kill
        // threshold worth showing headroom against; Android has none.
        final label = Platform.isIOS
            ? 'RAM ${_mb(bytes)}/${_mb(memoryBudgetBytes)} MB'
            : 'RAM ${_mb(bytes)} MB';
        return _Chip(colors: colors, label: label, dotColor: dotColor);
      },
    );
  }

  static int _mb(int bytes) => (bytes / (1024 * 1024)).round();
}
