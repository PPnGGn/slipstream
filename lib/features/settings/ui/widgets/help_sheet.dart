import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:slipstream/app/di/injector.dart';
import 'package:slipstream/core/theme/app_colors.dart';
import 'package:slipstream/core/theme/app_theme.dart';
import 'package:slipstream/core/theme/cubit/theme_cubit.dart';
import 'package:slipstream/core/ui/widgets/close_circle_button.dart';
import 'package:slipstream/core/ui/widgets/sheet_parts.dart';

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
        final colors = AppColors.of(context);
        final textTheme = Theme.of(context).textTheme;

        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                const SheetGrabber(),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    CloseCircleButton(
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
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
          Text(
            entry.title,
            style: textTheme.bodyLarge?.copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: AppDims.gapXs),
          Text(
            entry.body,
            style: textTheme.bodyMedium?.copyWith(
              color: colors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
