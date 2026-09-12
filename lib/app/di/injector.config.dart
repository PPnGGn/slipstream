// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:io' as _i497;

import 'package:get_it/get_it.dart' as _i174;
import 'package:injectable/injectable.dart' as _i526;
import 'package:shared_preferences/shared_preferences.dart' as _i460;
import 'package:talker_flutter/talker_flutter.dart' as _i207;

import '../../core/service/update_service/update_service_cubit.dart' as _i1021;
import '../../core/service/vpn_service/vpn_service_cubit.dart' as _i202;
import '../../core/theme/app_colors.dart' as _i962;
import '../../core/theme/cubit/theme_cubit.dart' as _i11;
import '../../core/theme/data/theme_store.dart' as _i802;
import '../../features/geo/cubit/geo_cubit.dart' as _i818;
import '../../features/geo/data/geo_config_gate.dart' as _i951;
import '../../features/geo/data/geo_paths.dart' as _i262;
import '../../features/geo/data/geo_repository.dart' as _i236;
import '../../features/geo/data/geo_update_service.dart' as _i196;
import '../../features/routing/cubit/ad_block_cubit.dart' as _i863;
import '../../features/routing/cubit/ru_bypass_cubit.dart' as _i1048;
import '../../features/routing/data/ad_block_store.dart' as _i117;
import '../../features/routing/data/local_proxy_gate.dart' as _i744;
import '../../features/routing/data/routing_policy_gate.dart' as _i194;
import '../../features/routing/data/ru_bypass_store.dart' as _i310;
import '../../features/subscriptions/cubit/subscriptions_cubit.dart' as _i83;
import '../../features/subscriptions/data/ping/ping_service.dart' as _i189;
import '../../features/subscriptions/data/selected_server_store.dart' as _i830;
import '../../features/subscriptions/data/subscription_factory.dart' as _i179;
import '../../features/subscriptions/data/subscription_parser/subscription_parser_service.dart'
    as _i302;
import '../../features/subscriptions/data/subscription_storage/subscription_storage.dart'
    as _i505;
import '../../features/update/data/update_repository.dart' as _i11;
import '../../features/update/data/updater_api.g.dart' as _i942;
import '../../features/vpn/data/vpn_api.g.dart' as _i482;
import '../../features/vpn/data/vpn_event_receiver.dart' as _i924;
import '../../features/vpn/data/vpn_repository.dart' as _i1056;
import '../../features/vpn/data/vpn_session_store.dart' as _i871;
import '../../features/vpn/data/xray_log_store.dart' as _i490;
import 'logger_module.dart' as _i987;
import 'prefs_module.dart' as _i891;
import 'storage_module.dart' as _i371;
import 'updater_module.dart' as _i884;
import 'vpn_module.dart' as _i731;

extension GetItInjectableX on _i174.GetIt {
  // initializes the registration of main-scope dependencies inside of GetIt
  Future<_i174.GetIt> init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) async {
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    final prefsModule = _$PrefsModule();
    final loggerModule = _$LoggerModule();
    final updaterModule = _$UpdaterModule();
    final vpnModule = _$VpnModule();
    final storageModule = _$StorageModule();
    await gh.singletonAsync<_i460.SharedPreferences>(
      () => prefsModule.prefs,
      preResolve: true,
    );
    gh.lazySingleton<_i207.Talker>(() => loggerModule.talker);
    gh.lazySingleton<_i942.UpdateInstaller>(
      () => updaterModule.updateInstaller,
    );
    gh.lazySingleton<_i482.VpnConnection>(() => vpnModule.vpnConnection);
    gh.lazySingleton<_i924.NativeVpnEventReceiver>(
      () => vpnModule.vpnEventReceiver,
    );
    gh.lazySingleton<_i744.LocalProxyPort>(() => _i744.LocalProxyPort());
    gh.lazySingleton<_i189.PingService>(() => _i189.PingService());
    gh.lazySingleton<_i179.SubscriptionFactory>(
      () => _i179.SubscriptionFactory(),
    );
    gh.lazySingleton<_i490.XrayLogStore>(
      () => _i490.XrayLogStore(),
      dispose: (i) => i.dispose(),
    );
    gh.lazySingleton<_i951.GeoConfigGate>(
      () => _i951.GeoConfigGate(gh<_i207.Talker>()),
    );
    gh.lazySingleton<_i744.LocalProxyGate>(
      () => _i744.LocalProxyGate(gh<_i207.Talker>()),
    );
    gh.lazySingleton<_i194.RoutingPolicyGate>(
      () => _i194.RoutingPolicyGate(gh<_i207.Talker>()),
    );
    await gh.singletonAsync<_i505.SubscriptionStorage>(
      () => storageModule.subscriptionStorage(gh<_i207.Talker>()),
      preResolve: true,
    );
    gh.lazySingleton<_i302.SubscriptionParserService>(
      () => _i302.SubscriptionParserService(gh<_i207.Talker>()),
    );
    await gh.singletonAsync<_i497.Directory>(
      () => updaterModule.updatesDir,
      instanceName: 'updatesDir',
      preResolve: true,
    );
    gh.lazySingleton<_i802.ThemeStore>(
      () => _i802.ThemeStore(gh<_i460.SharedPreferences>()),
    );
    gh.lazySingleton<_i117.AdBlockStore>(
      () => _i117.AdBlockStore(gh<_i460.SharedPreferences>()),
    );
    gh.lazySingleton<_i310.RuBypassStore>(
      () => _i310.RuBypassStore(gh<_i460.SharedPreferences>()),
    );
    gh.lazySingleton<_i830.SelectedServerStore>(
      () => _i830.SelectedServerStore(gh<_i460.SharedPreferences>()),
    );
    gh.lazySingleton<_i871.VpnSessionStore>(
      () => _i871.VpnSessionStore(gh<_i460.SharedPreferences>()),
    );
    gh.lazySingleton<_i863.AdBlockCubit>(
      () => _i863.AdBlockCubit(store: gh<_i117.AdBlockStore>()),
    );
    gh.lazySingleton<_i262.GeoPaths>(
      () => _i262.GeoPaths(gh<_i482.VpnConnection>(), gh<_i207.Talker>()),
    );
    gh.lazySingleton<_i236.GeoRepository>(
      () => _i236.GeoRepository(
        gh<_i262.GeoPaths>(),
        gh<_i207.Talker>(),
        gh<_i744.LocalProxyPort>(),
      ),
      dispose: (i) => i.dispose(),
    );
    gh.lazySingleton<_i11.UpdateRepository>(
      () => _i11.UpdateRepository(
        gh<_i207.Talker>(),
        gh<_i942.UpdateInstaller>(),
        gh<_i497.Directory>(instanceName: 'updatesDir'),
      ),
      dispose: (i) => i.dispose(),
    );
    gh.lazySingleton<_i11.AppThemeCubit>(
      () => _i11.AppThemeCubit(themeStore: gh<_i802.ThemeStore>()),
    );
    gh.lazySingleton<_i1021.UpdateServiceCubit>(
      () => _i1021.UpdateServiceCubit(
        repository: gh<_i11.UpdateRepository>(),
        talker: gh<_i207.Talker>(),
      ),
    );
    gh.lazySingleton<_i818.GeoCubit>(
      () => _i818.GeoCubit(
        repository: gh<_i236.GeoRepository>(),
        talker: gh<_i207.Talker>(),
      ),
    );
    gh.lazySingleton<_i1048.RuBypassCubit>(
      () => _i1048.RuBypassCubit(store: gh<_i310.RuBypassStore>()),
    );
    gh.lazySingleton<_i962.AppColors>(
      () => _i962.AppColors(themeCubit: gh<_i11.AppThemeCubit>()),
    );
    gh.lazySingleton<_i1056.VpnRepository>(
      () => _i1056.VpnRepository(
        gh<_i207.Talker>(),
        gh<_i482.VpnConnection>(),
        gh<_i924.NativeVpnEventReceiver>(),
        gh<_i490.XrayLogStore>(),
        gh<_i951.GeoConfigGate>(),
        gh<_i818.GeoCubit>(),
        gh<_i262.GeoPaths>(),
        gh<_i744.LocalProxyGate>(),
        gh<_i744.LocalProxyPort>(),
        gh<_i194.RoutingPolicyGate>(),
        gh<_i1048.RuBypassCubit>(),
        gh<_i863.AdBlockCubit>(),
      ),
      dispose: (i) => i.dispose(),
    );
    gh.lazySingleton<_i202.VpnServiceCubit>(
      () => _i202.VpnServiceCubit(
        repository: gh<_i1056.VpnRepository>(),
        sessionStore: gh<_i871.VpnSessionStore>(),
        talker: gh<_i207.Talker>(),
      ),
    );
    gh.lazySingleton<_i196.GeoUpdateService>(
      () => _i196.GeoUpdateService(
        gh<_i818.GeoCubit>(),
        gh<_i202.VpnServiceCubit>(),
        gh<_i207.Talker>(),
      ),
      dispose: (i) => i.dispose(),
    );
    gh.lazySingleton<_i83.SubscriptionsCubit>(
      () => _i83.SubscriptionsCubit(
        parser: gh<_i302.SubscriptionParserService>(),
        storage: gh<_i505.SubscriptionStorage>(),
        selectedServerStore: gh<_i830.SelectedServerStore>(),
        factory: gh<_i179.SubscriptionFactory>(),
        vpnServiceCubit: gh<_i202.VpnServiceCubit>(),
        talker: gh<_i207.Talker>(),
      ),
    );
    return this;
  }
}

class _$PrefsModule extends _i891.PrefsModule {}

class _$LoggerModule extends _i987.LoggerModule {}

class _$UpdaterModule extends _i884.UpdaterModule {}

class _$VpnModule extends _i731.VpnModule {}

class _$StorageModule extends _i371.StorageModule {}
