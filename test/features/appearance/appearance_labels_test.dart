import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream/core/theme/data/app_theme_mode.dart';
import 'package:slipstream/features/appearance/data/home_layout.dart';
import 'package:slipstream/features/appearance/ui/appearance_labels.dart';
import 'package:slipstream/features/language/data/app_language.dart';
import 'package:slipstream/features/subscriptions/data/auto_update/auto_update_interval.dart';
import 'package:slipstream/features/subscriptions/ui/auto_update_labels.dart';

import '../../helpers/l10n.dart';

void main() {
  test('theme and layout names', () {
    expect(AppThemeMode.light.label(l10nEn), 'Light');
    expect(AppThemeMode.phosphor.hint(l10nEn), contains('terminal-green'));
    expect(HomeLayout.compact.label(l10nEn), 'Compact');
    expect(HomeLayout.classic.hint(l10nEn), 'Big ring above the list');
  });

  group('the Appearance row of Settings', () {
    test('names the layout and the chosen language', () {
      expect(
        appearanceSubtitle(
          l10nEn,
          layout: HomeLayout.classic,
          language: AppLanguage.ru,
        ),
        'Classic layout · Русский',
      );
    });

    test('System is written in the current language', () {
      expect(
        appearanceSubtitle(
          l10nEn,
          layout: HomeLayout.compact,
          language: AppLanguage.system,
        ),
        'Compact layout · System',
      );
      expect(
        appearanceSubtitle(
          l10nRu,
          layout: HomeLayout.compact,
          language: AppLanguage.system,
        ),
        'Вид: Компактный · Системный',
      );
    });

    test('every other language is written in itself', () {
      for (final language in AppLanguage.values) {
        if (language == AppLanguage.system) continue;
        expect(
          languageNativeName(l10nEn, language),
          languageNativeName(l10nRu, language),
        );
      }
    });
  });

  group('auto-update intervals', () {
    test('off, one hour and several hours', () {
      expect(AutoUpdateInterval.off.label(l10nEn), 'Off');
      expect(AutoUpdateInterval.h1.label(l10nEn), 'Every hour');
      expect(AutoUpdateInterval.h6.label(l10nEn), 'Every 6 hours');
    });

    test('Russian declines the hours', () {
      expect(AutoUpdateInterval.h1.label(l10nRu), 'Каждый час');
      expect(AutoUpdateInterval.h3.label(l10nRu), 'Каждые 3 часа');
      expect(AutoUpdateInterval.h6.label(l10nRu), 'Каждые 6 часов');
      expect(AutoUpdateInterval.h24.label(l10nRu), 'Каждые 24 часа');
    });
  });
}
