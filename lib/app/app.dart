import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:slipstream/app/di/injector.dart';
import 'package:slipstream/core/service/update_service/update_service_cubit.dart';
import 'package:slipstream/core/service/vpn_service/vpn_service_cubit.dart';
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
            return _UpdaterHost(child: child ?? const SizedBox.shrink());
          },
        );
      },
    );
  }
}

class _UpdaterHost extends StatefulWidget {
  const _UpdaterHost({required this.child});

  final Widget child;

  @override
  State<_UpdaterHost> createState() => _UpdaterHostState();
}

class _UpdaterHostState extends State<_UpdaterHost> {
  final _updateCubit = getIt<UpdateServiceCubit>();
  final _vpnCubit = getIt<VpnServiceCubit>();
  AppLifecycleListener? _lifecycle;
  var _retriedWhileVpnOn = false;

  @override
  void initState() {
    super.initState();
    if (!Platform.isAndroid) return;
    _lifecycle = AppLifecycleListener(onResume: _retryIfNeeded);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_updateCubit.check());
    });
  }

  void _retryIfNeeded() {
    if (!Platform.isAndroid) return;
    final shouldRetry = _updateCubit.state.maybeWhen(
      idle: () => true,
      error: (_) => true,
      orElse: () => false,
    );
    if (shouldRetry) unawaited(_updateCubit.check());
  }

  bool get _vpnConnected => _vpnCubit.state.maybeWhen(
    connected: (_, _, _, _) => true,
    orElse: () => false,
  );

  void _retryOnceIfVpnAlreadyOn() {
    if (_retriedWhileVpnOn || !_vpnConnected) return;
    _retriedWhileVpnOn = true;
    _retryIfNeeded();
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isAndroid) return widget.child;

    return BlocListener<VpnServiceCubit, VpnState>(
      bloc: _vpnCubit,
      listenWhen: (previous, current) {
        final wasConnected = previous.maybeWhen(
          connected: (_, _, _, _) => true,
          orElse: () => false,
        );
        final nowConnected = current.maybeWhen(
          connected: (_, _, _, _) => true,
          orElse: () => false,
        );
        return nowConnected && !wasConnected;
      },
      listener: (_, _) {
        _retriedWhileVpnOn = false;
        _retryIfNeeded();
      },
      child: BlocListener<UpdateServiceCubit, UpdateState>(
        bloc: _updateCubit,
        listenWhen: (previous, current) {
          final wasChecking = previous.maybeWhen(
            checking: () => true,
            orElse: () => false,
          );
          final failed = current.maybeWhen(
            idle: () => true,
            error: (_) => true,
            orElse: () => false,
          );
          return wasChecking && failed;
        },
        listener: (_, _) => _retryOnceIfVpnAlreadyOn(),
        child: BlocListener<UpdateServiceCubit, UpdateState>(
          bloc: _updateCubit,
          listenWhen: (previous, current) {
            final wasReady = previous.maybeWhen(
              readyToInstall: (_, _) => true,
              orElse: () => false,
            );
            final nowReady = current.maybeWhen(
              readyToInstall: (_, _) => true,
              orElse: () => false,
            );
            return nowReady && !wasReady;
          },
          listener: (context, _) => showUpdateDialog(context),
          child: widget.child,
        ),
      ),
    );
  }
}
