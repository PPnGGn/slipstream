import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:slipstream/app/di/injector.dart';
import 'package:slipstream/core/theme/app_colors.dart';
import 'package:slipstream/features/ping/data/ping_settings_store.dart';
import 'package:slipstream/features/ping/domain/entities/ping_round_result.dart';
import 'package:slipstream/features/ping/presentation/ping_cubit.dart';
import 'package:slipstream/features/ping/presentation/ping_entry.dart';

/// Latency indicator for one server row. Reads its own entry out of
/// the ping cubit via a selector, so a patch to one server's entry
/// never rebuilds every other row's badge — and renders either a
/// value pill or a compact dot per the persisted display mode
/// (spec: "Два режима").
class PingBadge extends StatelessWidget {
  const PingBadge({super.key, required this.serverId, required this.colors});

  final String serverId;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<PingCubit, PingViewState, (PingEntry, PingDisplayMode)>(
      bloc: getIt<PingCubit>(),
      selector: (view) => (
        view.entries[serverId] ?? const PingEntry.notTested(),
        view.displayMode,
      ),
      builder: (context, selected) {
        final (entry, mode) = selected;
        return mode == PingDisplayMode.dots
            ? _PingDot(colors: colors, entry: entry)
            : PingPill(colors: colors, entry: entry);
      },
    );
  }
}

/// The value pill from the design (design/SlipStream Design.dc.html:
/// a colored dot + "23 ms" in a rounded chip). Public: also used on
/// the connection card and the server info sheet.
class PingPill extends StatelessWidget {
  const PingPill({super.key, required this.colors, required this.entry});

  final AppColors colors;
  final PingEntry entry;

  @override
  Widget build(BuildContext context) {
    final style = _pillStyle(colors, entry);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 5,
        children: [
          style.marker,
          _PillLabel(text: style.label, color: style.foreground, live: style.live),
        ],
      ),
    );
  }
}

class _PillLabel extends StatelessWidget {
  const _PillLabel({required this.text, required this.color, required this.live});

  final String text;
  final Color color;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final label = Text(
      text,
      style: TextStyle(
        fontFamily: 'monospace',
        fontFeatures: const [FontFeature.tabularFigures()],
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: color,
      ),
    );
    return live ? _Pulsing(child: label) : label;
  }
}

class _PillStyle {
  const _PillStyle({
    required this.background,
    required this.foreground,
    required this.marker,
    required this.label,
    this.live = false,
  });

  final Color background;
  final Color foreground;
  final Widget marker;
  final String label;
  final bool live;
}

_PillStyle _pillStyle(AppColors colors, PingEntry entry) {
  switch (entry.status) {
    case PingRunStatus.measured:
      final color = _qualityColor(colors, entry.latencyMs!);
      return _PillStyle(
        background: color.withValues(alpha: 0.15),
        foreground: color,
        marker: _Dot(color: color),
        label: '${entry.latencyMs!.round()} ms',
      );
    case PingRunStatus.dead:
      return _PillStyle(
        background: colors.danger.withValues(alpha: 0.15),
        foreground: colors.danger,
        marker: Icon(Icons.close, size: 9, color: colors.danger),
        label: _failureLabel(entry.failureReason),
      );
    case PingRunStatus.queued:
    case PingRunStatus.measuring:
      return _PillStyle(
        background: colors.chip,
        foreground: colors.textMuted,
        marker: _Dot(color: colors.textMuted),
        label: '···',
        live: true,
      );
    case PingRunStatus.notTested:
      return _PillStyle(
        background: colors.chip,
        foreground: colors.textMuted,
        marker: _Dot(color: colors.textMuted.withValues(alpha: 0.5)),
        label: '—',
      );
    case PingRunStatus.unsupported:
      return _PillStyle(
        background: colors.chip,
        foreground: colors.textMuted,
        marker: _Dot(color: colors.textMuted, outlined: true),
        label: 'n/a',
      );
  }
}

Color _qualityColor(AppColors colors, double latencyMs) =>
    switch (pingQualityOf(latencyMs)) {
      PingQuality.good => colors.ok,
      PingQuality.medium => colors.warn,
      PingQuality.poor => colors.danger,
    };

String _failureLabel(PingFailureReason? reason) => switch (reason) {
  PingFailureReason.refused => 'refused',
  PingFailureReason.dns => 'no dns',
  PingFailureReason.error => 'error',
  PingFailureReason.timeout || null => 'timeout',
};

class _PingDot extends StatelessWidget {
  const _PingDot({required this.colors, required this.entry});

  final AppColors colors;
  final PingEntry entry;

  @override
  Widget build(BuildContext context) {
    return switch (entry.status) {
      PingRunStatus.notTested => _Dot(
        color: colors.textMuted.withValues(alpha: 0.35),
        size: 10,
      ),
      PingRunStatus.queued || PingRunStatus.measuring => _Pulsing(
        child: _Dot(color: colors.textMuted, size: 10),
      ),
      // A plain red dot here would be indistinguishable from a merely
      // slow ("poor") server, which also renders red — the whole
      // point of telling dead apart from slow. A cross reads as "down"
      // regardless of color overlap with the quality scale.
      PingRunStatus.dead => Icon(Icons.close, size: 12, color: colors.danger),
      PingRunStatus.unsupported => _Dot(
        color: colors.textMuted,
        size: 10,
        outlined: true,
      ),
      PingRunStatus.measured => _Dot(
        color: _qualityColor(colors, entry.latencyMs!),
        size: 10,
      ),
    };
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color, this.size = 5, this.outlined = false});

  final Color color;
  final double size;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: outlined ? Colors.transparent : color,
        border: outlined ? Border.all(color: color, width: 1.6) : null,
      ),
    );
  }
}

/// Shared pulse animation for anything "in progress": the queued/
/// measuring dot and the "···" pill label.
class _Pulsing extends StatefulWidget {
  const _Pulsing({required this.child});

  final Widget child;

  @override
  State<_Pulsing> createState() => _PulsingState();
}

class _PulsingState extends State<_Pulsing> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.3, end: 1.0).animate(_controller),
      child: widget.child,
    );
  }
}
