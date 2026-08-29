import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:slipstream/app/app_assets.dart';
import 'package:slipstream/app/di/injector.dart';
import 'package:slipstream/core/theme/app_colors.dart';
import 'package:slipstream/core/theme/app_theme.dart';
import 'package:slipstream/core/theme/cubit/theme_cubit.dart';
import 'package:slipstream/core/ui/widgets/app_icon_button.dart';
import 'package:slipstream/core/ui/widgets/vpn_connection_card.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final themeCubit = getIt<AppThemeCubit>();

    return BlocBuilder<AppThemeCubit, AppThemeMode>(
      bloc: themeCubit,
      builder: (context, state) {
        final isDark = state == AppThemeMode.dark;

        return Scaffold(
          appBar: AppBar(
            leadingWidth: 44,
            titleSpacing: 4,
            actionsPadding: EdgeInsets.symmetric(
              horizontal: AppDims.horizontalPadding,
            ),
            backgroundColor: Colors.transparent,
            title: const Text('SlipSstream'),
            leading: CustomIconButton(
              onTap: () {},
              iconPath: AppAssets.appIcon,
            ),
            actions: [
              CustomIconButton(
                onTap: themeCubit.toggleTheme,
                borderColor: getIt<AppColors>().border,
                iconPath: isDark ? AppAssets.moonShine : AppAssets.sunFilled,
              ),
            ],
          ),
          extendBodyBehindAppBar: true,
          body: SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              padding: .all(16),
              child: Column(children: [VPNConectionCard()]),
            ),
          ),
        );
      },
    );
  }
}

