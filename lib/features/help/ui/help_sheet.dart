import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:slipstream/app/app_assets.dart';
import 'package:slipstream/app/di/injector.dart';
import 'package:slipstream/core/theme/app_colors.dart';
import 'package:slipstream/core/theme/cubit/theme_cubit.dart';
import 'package:slipstream/core/ui/widgets/icon_tile.dart';
import 'package:slipstream/core/ui/widgets/sheet_parts.dart';
import 'package:slipstream/features/help/ui/help_topic.dart';

/// Opens the help sheet of a settings page. The sheet only draws [topic]; the
/// texts live in help_topics.dart.
Future<void> showHelpSheet(BuildContext context, HelpTopic topic) {
  final media = MediaQuery.of(context);
  final maxHeight =
      media.size.height - media.viewPadding.top - kToolbarHeight - 8;

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    constraints: BoxConstraints(maxHeight: maxHeight),
    builder: (context) => _HelpSheet(topic: topic),
  );
}

class _HelpSheet extends StatelessWidget {
  const _HelpSheet({required this.topic});

  final HelpTopic topic;

  @override
  Widget build(BuildContext context) {
    // A sheet lives in its own route, so it does not rebuild with the page
    // when the theme changes; this builder repaints it.
    return BlocBuilder<AppThemeCubit, AppThemeState>(
      bloc: getIt<AppThemeCubit>(),
      builder: (context, _) {
        final colors = AppColors.of(context);

        return SafeArea(
          top: false,
          child: Padding(
            padding: const .fromLTRB(20, 8, 20, 0),
            child: Column(
              crossAxisAlignment: .stretch,
              mainAxisSize: .min,
              children: [
                const SheetGrabber(),
                SheetTitleRow(
                  iconPath: AppAssets.info,
                  title: topic.title,
                  subtitle: 'How it works',
                ),
                const SizedBox(height: 14),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const .only(bottom: 24),
                    child: Column(
                      crossAxisAlignment: .stretch,
                      spacing: 10,
                      children: [
                        Padding(
                          padding: const .fromLTRB(2, 0, 2, 6),
                          child: Text(
                            topic.intro,
                            style: TextStyle(
                              fontSize: 13.5,
                              height: 1.5,
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                        for (final item in topic.items)
                          _ItemCard(item: item, colors: colors),
                        if (topic.notes.isNotEmpty)
                          _NotesCard(notes: topic.notes, colors: colors),
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

/// One setting: its icon and name as on the page, then what it does and why
/// it is needed, and an optional tip.
class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item, required this.colors});

  final HelpItem item;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const .all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: .circular(18),
        border: .all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: .stretch,
        spacing: 12,
        children: [
          Row(
            spacing: 12,
            children: [
              IconTile(
                iconPath: item.iconPath,
                color: colors.tileHue(item.hue),
              ),
              Expanded(
                child: Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: .w600,
                    color: colors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          _Block(label: 'What it does', text: item.what, colors: colors),
          _Block(label: 'Why it matters', text: item.why, colors: colors),
          if (item.tip case final tip?) _Tip(text: tip, colors: colors),
        ],
      ),
    );
  }
}

/// A mono caps label over a paragraph.
class _Block extends StatelessWidget {
  const _Block({required this.label, required this.text, required this.colors});

  final String label;
  final String text;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: .start,
      spacing: 4,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 9.5,
            fontWeight: .w600,
            letterSpacing: 0.8,
            color: colors.textMuted,
          ),
        ),
        Text(
          text,
          style: TextStyle(
            fontSize: 12.5,
            height: 1.5,
            color: colors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _Tip extends StatelessWidget {
  const _Tip({required this.text, required this.colors});

  final String text;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const .symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.primarySoft,
        borderRadius: .circular(12),
      ),
      child: Row(
        crossAxisAlignment: .start,
        spacing: 8,
        children: [
          Padding(
            padding: const .only(top: 2),
            child: SvgPicture.asset(
              AppAssets.check,
              width: 13,
              height: 13,
              colorFilter: .mode(colors.accentIcon, .srcIn),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                height: 1.45,
                fontWeight: .w500,
                color: colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Good to know": when changes apply, exceptions, legends.
class _NotesCard extends StatelessWidget {
  const _NotesCard({required this.notes, required this.colors});

  final List<HelpNote> notes;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        Padding(
          padding: const .fromLTRB(4, 10, 4, 8),
          child: Text(
            'GOOD TO KNOW',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 10,
              fontWeight: .w700,
              letterSpacing: 1.4,
              color: colors.textMuted,
            ),
          ),
        ),
        Container(
          padding: const .all(14),
          decoration: BoxDecoration(
            color: colors.chip,
            borderRadius: .circular(18),
          ),
          child: Column(
            crossAxisAlignment: .stretch,
            children: [
              for (final (i, note) in notes.indexed) ...[
                if (i > 0)
                  Padding(
                    padding: const .symmetric(vertical: 12),
                    child: Divider(height: 1, color: colors.border),
                  ),
                Column(
                  crossAxisAlignment: .start,
                  spacing: 4,
                  children: [
                    Text(
                      note.title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: .w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    Text(
                      note.body,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
