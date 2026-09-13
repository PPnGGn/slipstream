import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:slipstream/app/di/injector.dart';
import 'package:slipstream/core/theme/app_colors.dart';
import 'package:slipstream/core/theme/app_theme.dart';
import 'package:slipstream/core/theme/cubit/theme_cubit.dart';

class HelpEntry {
  const HelpEntry({required this.title, required this.body});

  final String title;
  final String body;
}

Future<void> showHelpSheet(
  BuildContext context, {
  required String title,
  required List<HelpEntry> entries,
}) {
  final media = MediaQuery.of(context);
  final maxHeight =
      media.size.height - media.viewPadding.top - kToolbarHeight - 8;

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    constraints: BoxConstraints(maxHeight: maxHeight),
    builder: (context) => _HelpSheet(title: title, entries: entries),
  );
}

class _HelpSheet extends StatelessWidget {
  const _HelpSheet({required this.title, required this.entries});

  final String title;
  final List<HelpEntry> entries;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppThemeCubit, AppThemeState>(
      bloc: getIt<AppThemeCubit>(),
      builder: (context, _) {
        final colors = getIt<AppColors>();
        final textTheme = Theme.of(context).textTheme;

        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: colors.border,
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                ),
                Text(title, style: textTheme.titleMedium),
                const SizedBox(height: 8),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < entries.length; i++)
                          _HelpEntryTile(
                            entry: entries[i],
                            textTheme: textTheme,
                            colors: colors,
                            isLast: i == entries.length - 1,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HelpEntryTile extends StatelessWidget {
  const _HelpEntryTile({
    required this.entry,
    required this.textTheme,
    required this.colors,
    this.isLast = false,
  });

  final HelpEntry entry;
  final TextTheme textTheme;
  final AppColors colors;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : AppDims.gapL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(entry.title, style: textTheme.bodyLarge),
          const SizedBox(height: AppDims.gapXs),
          Text(
            entry.body,
            style: textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}
