import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:slipstream/app/app_assets.dart';
import 'package:slipstream/app/di/injector.dart';
import 'package:slipstream/core/theme/app_colors.dart';
import 'package:slipstream/core/theme/app_theme.dart';
import 'package:slipstream/core/theme/cubit/theme_cubit.dart';
import 'package:slipstream/core/ui/widgets/custom_icon_button.dart';
import 'package:slipstream/features/subscriptions/ui/widgets/add_subscription_sheet.dart';
import 'package:slipstream/features/subscriptions/ui/widgets/server_list.dart';
import 'package:slipstream/features/subscriptions/ui/widgets/subscription_search_bar.dart';
import 'package:slipstream/features/vpn/ui/widgets/connection_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeCubit = getIt<AppThemeCubit>();

    return BlocBuilder<AppThemeCubit, AppThemeMode>(
      bloc: themeCubit,
      builder: (context, state) {
        final isDark = state == AppThemeMode.dark;

        return Scaffold(
          appBar: AppBar(
            titleSpacing: 12,
            leadingWidth: AppDims.horizontalPadding + 40,
            actionsPadding: const .symmetric(
              horizontal: AppDims.horizontalPadding,
            ),
            title: const Text('SlipStream'),
            leading: Padding(
              padding: const .only(left: AppDims.horizontalPadding),
              child: Center(
                child: CustomIconButton(
                  onTap: () => context.push('/settings'),
                  iconPath: AppAssets.wave,
                  gradientColors: getIt<AppColors>().brandGradient,
                ),
              ),
            ),
            actions: [
              Center(
                child: CustomIconButton(
                  onTap: themeCubit.toggleTheme,
                  borderColor: getIt<AppColors>().border,
                  iconPath: isDark ? AppAssets.moonShine : AppAssets.sunFilled,
                ),
              ),
            ],
          ),
          extendBodyBehindAppBar: true,
          body: SafeArea(
            bottom: false,
            child: Padding(
              padding: const .symmetric(horizontal: 16, vertical: 4),
              child: Column(
                spacing: 16,
                children: [
                  const ConnectionCard(),
                  SubscriptionSearchBar(
                    colors: getIt<AppColors>(),
                    controller: _search,
                    onAddSubscription: () => showAddSubscriptionSheet(context),
                  ),
                  Expanded(
                    child: AnimatedBuilder(
                      animation: _search,
                      builder: (context, _) => ServerList(
                        query: _search.text,
                        onAddSubscription: () =>
                            showAddSubscriptionSheet(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
