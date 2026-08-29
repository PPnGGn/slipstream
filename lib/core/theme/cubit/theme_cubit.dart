import 'package:bloc/bloc.dart';
import 'package:injectable/injectable.dart';

enum AppThemeMode { light, dark }

@LazySingleton()
class AppThemeCubit extends Cubit<AppThemeMode> {
  AppThemeCubit() : super(AppThemeMode.light);

  bool get isDark => state == AppThemeMode.dark;

  void toggleTheme() {
    emit(state == AppThemeMode.light ? AppThemeMode.dark : AppThemeMode.light);
  }
}
