enum AppThemeMode { light, dark, system }

class AppThemeState {
  const AppThemeState({required this.mode, required this.isDark});

  final AppThemeMode mode;
  final bool isDark;

  @override
  bool operator ==(Object other) =>
      other is AppThemeState && other.mode == mode && other.isDark == isDark;

  @override
  int get hashCode => Object.hash(mode, isDark);
}
