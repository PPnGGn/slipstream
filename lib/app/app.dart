import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:slipstream/app/di/injector.dart';
import 'package:slipstream/core/service/update_service/update_service_cubit.dart';
import 'package:slipstream/core/theme/app_theme.dart';
import 'package:slipstream/core/theme/cubit/theme_cubit.dart';
import 'package:slipstream/features/update/ui/widgets/update_dialog.dart';
import 'router.dart';

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeCubit = getIt<AppThemeCubit>();

    return BlocBuilder<AppThemeCubit, AppThemeMode>(
      bloc: themeCubit,
      builder: (context, state) {
        return MaterialApp.router(
          routerConfig: appRouter,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: state == AppThemeMode.dark
              ? ThemeMode.dark
              : ThemeMode.light,
          builder: (context, child) {
            return BlocListener<UpdateServiceCubit, UpdateState>(
              bloc: getIt<UpdateServiceCubit>(),
              listener: (context, state) {
                final available = state.maybeWhen(
                  available: (_) => true,
                  orElse: () => false,
                );
                if (available) showUpdateDialog(context);
              },
              child: child,
            );
          },
        );
      },
    );
  }
}
