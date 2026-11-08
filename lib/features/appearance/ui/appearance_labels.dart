import 'package:slipstream/core/theme/data/app_theme_mode.dart';
import 'package:slipstream/features/appearance/data/home_layout.dart';
import 'package:slipstream/features/language/data/app_language.dart';
import 'package:slipstream/l10n/l10n_context.dart';

extension AppThemeModeLabels on AppThemeMode {
  String label(AppLocalizations l10n) => switch (this) {
    AppThemeMode.light => l10n.themeLight,
    AppThemeMode.dark => l10n.themeDark,
    AppThemeMode.phosphor => l10n.themePhosphor,
  };

  String hint(AppLocalizations l10n) => switch (this) {
    AppThemeMode.light => l10n.themeLightHint,
    AppThemeMode.dark => l10n.themeDarkHint,
    AppThemeMode.phosphor => l10n.themePhosphorHint,
  };
}

extension HomeLayoutLabels on HomeLayout {
  String label(AppLocalizations l10n) => switch (this) {
    HomeLayout.classic => l10n.layoutClassic,
    HomeLayout.compact => l10n.layoutCompact,
  };

  String hint(AppLocalizations l10n) => switch (this) {
    HomeLayout.classic => l10n.layoutClassicHint,
    HomeLayout.compact => l10n.layoutCompactHint,
  };
}

/// A language written in itself, so a reader who cannot read the current
/// language still finds theirs. System has no name of its own.
String languageNativeName(AppLocalizations l10n, AppLanguage language) =>
    switch (language) {
      AppLanguage.system => l10n.languageSystem,
      AppLanguage.en => 'English',
      AppLanguage.ru => 'Русский',
      AppLanguage.zh => '中文',
      AppLanguage.fa => 'فارسی',
    };

/// The line under "Appearance" in Settings: the home layout and the language.
String appearanceSubtitle(
  AppLocalizations l10n, {
  required HomeLayout layout,
  required AppLanguage language,
}) => l10n.appearanceSubtitle(
  layout.label(l10n),
  languageNativeName(l10n, language),
);
