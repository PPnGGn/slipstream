import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:slipstream/app/app_assets.dart';
import 'package:slipstream/app/di/injector.dart';
import 'package:slipstream/core/theme/app_colors.dart';
import 'package:slipstream/core/theme/cubit/theme_cubit.dart';
import 'package:slipstream/features/diagnostics/cubit/memory_monitor_cubit.dart';
import 'package:slipstream/features/diagnostics/cubit/memory_usage_cubit.dart';
import 'package:slipstream/features/diagnostics/data/memory_monitor_mode.dart';
import 'package:slipstream/features/diagnostics/ui/memory_line_view.dart';

/// `[chip] 23 MB · Normal`: one thin line on the home screen, above the
/// connection bar (compact layout) or under the card (classic). Draws nothing
/// while the monitor is off in settings. [padding] belongs to the line, so
/// that nothing is left behind when it is hidden.
class MemoryMonitorLine extends StatelessWidget {
  const MemoryMonitorLine({super.key, required this.padding});

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MemoryMonitorCubit, MemoryMonitorMode>(
      bloc: getIt<MemoryMonitorCubit>(),
      builder: (context, mode) {
        if (!mode.enabled) return const SizedBox.shrink();

        return BlocBuilder<AppThemeCubit, AppThemeState>(
          bloc: getIt<AppThemeCubit>(),
          builder: (context, _) => BlocBuilder<MemoryUsageCubit, MemoryUsage>(
            bloc: getIt<MemoryUsageCubit>(),
            builder: (context, usage) => Padding(
              padding: padding,
              child: _Line(
                colors: getIt<AppColors>(),
                view: memoryLineView(usage, ios: Platform.isIOS),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.colors, required this.view});

  final AppColors colors;
  final MemoryLineView view;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: 'monospace',
      fontFeatures: const [FontFeature.tabularFigures()],
      fontSize: 11,
      fontWeight: .w600,
    );
    final label = view.label;
    final healthColor = switch (view.health) {
      MemoryHealth.ok => colors.ok,
      MemoryHealth.warn => colors.warn,
      MemoryHealth.danger => colors.danger,
      null => colors.textMuted,
    };

    return Row(
      spacing: 6,
      children: [
        SvgPicture.asset(
          AppAssets.chip,
          width: 13,
          height: 13,
          colorFilter: .mode(colors.textMuted, .srcIn),
        ),
        Text(view.value, style: style.copyWith(color: healthColor)),
        if (label != null) ...[
          Text('·', style: style.copyWith(color: colors.textMuted)),
          Text(label, style: style.copyWith(color: healthColor)),
        ],
      ],
    );
  }
}
