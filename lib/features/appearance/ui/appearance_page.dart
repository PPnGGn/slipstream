import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:slipstream/app/app_assets.dart';
import 'package:slipstream/app/di/injector.dart';
import 'package:slipstream/core/theme/app_colors.dart';
import 'package:slipstream/core/theme/cubit/theme_cubit.dart';
import 'package:slipstream/core/ui/widgets/page_header.dart';
import 'package:slipstream/core/ui/widgets/radio_dot.dart';
import 'package:slipstream/features/appearance/cubit/home_layout_cubit.dart';
import 'package:slipstream/features/appearance/data/home_layout.dart';
import 'package:slipstream/features/appearance/ui/appearance_labels.dart';
import 'package:slipstream/features/appearance/ui/appearance_previews.dart';
import 'package:slipstream/features/language/cubit/language_cubit.dart';
import 'package:slipstream/features/language/data/app_language.dart';
import 'package:slipstream/l10n/l10n_context.dart';
import 'package:slipstream/features/settings/ui/widgets/settings_card.dart';

/// Settings → Appearance: theme, home layout and language.
/// Picking a card only calls a cubit; the cubits store the choice and the
/// whole app repaints from their state.
class AppearancePage extends StatelessWidget {
  const AppearancePage({super.key});

  @override
  Widget build(BuildContext context) {
    final themeCubit = getIt<AppThemeCubit>();
    final layoutCubit = getIt<HomeLayoutCubit>();

    return BlocBuilder<AppThemeCubit, AppThemeState>(
      bloc: themeCubit,
      builder: (context, theme) => BlocBuilder<HomeLayoutCubit, HomeLayout>(
        bloc: layoutCubit,
        builder: (context, layout) {
          final colors = AppColors.of(context);

          return Scaffold(
            body: SafeArea(
              child: Column(
                children: [
                  const PageHeader(title: 'Appearance'),
                  Expanded(
                    child: ListView(
                      padding: const .fromLTRB(16, 6, 16, 32),
                      children: [
                        const SectionHeader('Theme', top: 10),
                        Padding(
                          padding: const .symmetric(horizontal: 4),
                          child: Row(
                            spacing: 12,
                            crossAxisAlignment: .start,
                            children: [
                              for (final mode in AppThemeMode.values)
                                Expanded(
                                  child: _ChoiceCard(
                                    colors: colors,
                                    selected: mode == theme.mode,
                                    label: mode.label,
                                    frameHeight: 156,
                                    frameColor: AppThemeState(
                                      mode: mode,
                                    ).palette.background,
                                    onTap: () => themeCubit.setMode(mode),
                                    preview: ThemePreview(
                                      palette: AppThemeState(
                                        mode: mode,
                                      ).palette,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const .fromLTRB(4, 12, 4, 0),
                          child: Text(
                            theme.mode.hint,
                            textAlign: .center,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: colors.textMuted,
                            ),
                          ),
                        ),
                        const SectionHeader('Connection style', top: 26),
                        Padding(
                          padding: const .symmetric(horizontal: 4),
                          child: Row(
                            spacing: 12,
                            crossAxisAlignment: .start,
                            children: [
                              for (final option in HomeLayout.values)
                                Expanded(
                                  child: _ChoiceCard(
                                    colors: colors,
                                    selected: option == layout,
                                    label: option.label,
                                    hint: option.hint,
                                    frameHeight: 176,
                                    frameColor: colors.background,
                                    onTap: () => layoutCubit.setLayout(option),
                                    preview: option == HomeLayout.classic
                                        ? ClassicLayoutPreview(
                                            palette: colors.palette,
                                          )
                                        : CompactLayoutPreview(
                                            palette: colors.palette,
                                          ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        SectionHeader(context.l10n.appearanceLanguage, top: 26),
                        _LanguageSection(colors: colors),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The language list. The names are written in their own language on purpose
/// (a reader who cannot read the current language must still find theirs),
/// so only the System row comes from the translations.
class _LanguageSection extends StatelessWidget {
  const _LanguageSection({required this.colors});

  final AppColors colors;

  static const _flags = {
    AppLanguage.system: '🌐',
    AppLanguage.en: '🇬🇧',
    AppLanguage.ru: '🇷🇺',
    AppLanguage.zh: '🇨🇳',
    AppLanguage.fa: '🇮🇷',
  };

  static const _names = {
    AppLanguage.en: ('English', 'English'),
    AppLanguage.ru: ('Русский', 'Russian'),
    AppLanguage.zh: ('中文', 'Chinese'),
    AppLanguage.fa: ('فارسی', 'Persian'),
  };

  @override
  Widget build(BuildContext context) {
    final cubit = getIt<LanguageCubit>();

    return BlocBuilder<LanguageCubit, AppLanguage>(
      bloc: cubit,
      builder: (context, selected) => SettingsGroup(
        children: [
          for (final language in AppLanguage.values)
            _LanguageRow(
              colors: colors,
              flag: _flags[language]!,
              name: language == AppLanguage.system
                  ? context.l10n.languageSystem
                  : _names[language]!.$1,
              subtitle: language == AppLanguage.system
                  ? context.l10n.languageSystemHint
                  : _names[language]!.$2,
              selected: language == selected,
              onTap: () => cubit.setLanguage(language),
            ),
        ],
      ),
    );
  }
}

/// A preview frame with a radio and a label under it. The selected frame
/// gets a double ring: background gap, then the accent.
class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.colors,
    required this.selected,
    required this.label,
    required this.frameHeight,
    required this.frameColor,
    required this.onTap,
    required this.preview,
    this.hint,
  });

  final AppColors colors;
  final bool selected;
  final String label;
  final String? hint;
  final double frameHeight;
  final Color frameColor;
  final VoidCallback onTap;
  final Widget preview;

  @override
  Widget build(BuildContext context) {
    final labelStyle = TextStyle(
      fontSize: hint == null ? 13.5 : 14,
      fontWeight: .w600,
      color: selected ? colors.textPrimary : colors.textSecondary,
    );

    return GestureDetector(
      onTap: onTap,
      behavior: .opaque,
      child: Column(
        crossAxisAlignment: .stretch,
        spacing: 10,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: frameHeight,
            clipBehavior: .antiAlias,
            decoration: BoxDecoration(
              color: frameColor,
              borderRadius: .circular(16),
              boxShadow: selected
                  ? [
                      BoxShadow(color: colors.accentIcon, spreadRadius: 4),
                      BoxShadow(color: colors.background, spreadRadius: 2),
                    ]
                  : [BoxShadow(color: colors.border, spreadRadius: 1)],
            ),
            child: preview,
          ),
          if (hint == null)
            Row(
              mainAxisAlignment: .center,
              spacing: 7,
              children: [
                RadioDot(selected: selected),
                Flexible(
                  child: Text(
                    label,
                    style: labelStyle,
                    maxLines: 1,
                    overflow: .ellipsis,
                  ),
                ),
              ],
            )
          else
            Padding(
              padding: const .symmetric(horizontal: 2),
              child: Row(
                crossAxisAlignment: .start,
                spacing: 8,
                children: [
                  Padding(
                    padding: const .only(top: 2),
                    child: RadioDot(selected: selected),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: .start,
                      spacing: 1,
                      children: [
                        Text(label, style: labelStyle),
                        Text(
                          hint!,
                          style: TextStyle(
                            fontSize: 11,
                            color: colors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _LanguageRow extends StatelessWidget {
  const _LanguageRow({
    required this.colors,
    required this.flag,
    required this.name,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final AppColors colors;
  final String flag;
  final String name;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const .symmetric(horizontal: 14, vertical: 11),
        child: Row(
          spacing: 13,
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: .center,
              decoration: BoxDecoration(
                color: colors.surfaceRaised,
                borderRadius: .circular(11),
                border: .all(color: colors.border),
              ),
              child: Text(
                flag,
                style: const TextStyle(fontSize: 18, height: 1),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: .start,
                spacing: 2,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: .w500,
                      color: colors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11.5, color: colors.textMuted),
                  ),
                ],
              ),
            ),
            if (selected)
              Container(
                width: 22,
                height: 22,
                alignment: .center,
                decoration: BoxDecoration(
                  shape: .circle,
                  color: colors.accentIcon,
                ),
                child: SvgPicture.asset(
                  AppAssets.check,
                  width: 12,
                  height: 12,
                  colorFilter: .mode(colors.background, .srcIn),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
