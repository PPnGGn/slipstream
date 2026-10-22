import 'package:slipstream/core/theme/data/app_theme_mode.dart';
import 'package:slipstream/features/appearance/data/home_layout.dart';

extension AppThemeModeLabels on AppThemeMode {
  String get label => switch (this) {
    AppThemeMode.light => 'Light',
    AppThemeMode.dark => 'Dark',
    AppThemeMode.phosphor => 'Phosphor',
  };

  String get hint => switch (this) {
    AppThemeMode.light => 'Soft lavender paper — for daylight',
    AppThemeMode.dark => 'Ink-blue night',
    AppThemeMode.phosphor => 'True-black OLED with terminal-green accents',
  };
}

extension HomeLayoutLabels on HomeLayout {
  String get label => switch (this) {
    HomeLayout.classic => 'Classic',
    HomeLayout.compact => 'Compact',
  };

  String get hint => switch (this) {
    HomeLayout.classic => 'Big ring above the list',
    HomeLayout.compact => 'Slim bar at the bottom',
  };
}
