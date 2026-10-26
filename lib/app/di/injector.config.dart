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
import '../../core/theme/cubit/theme_cubit.dart' as _i12;
import '../../core/theme/data/theme_store.dart' as _i802;
import '../../features/appearance/cubit/home_layout_cubit.dart' as _i304;
import '../../features/appearance/data/home_layout_store.dart' as _i979;
import '../../features/client_identity/data/client_identity_repository.dart'
    as _i568;
import '../../features/client_identity/data/client_identity_store.dart'
    as _i407;
import '../../features/client_identity/data/device_info_api.g.dart' as _i1033;
import '../../features/diagnostics/cubit/memory_monitor_cubit.dart' as _i628;
import '../../features/diagnostics/cubit/memory_usage_cubit.dart' as _i190;
import '../../features/diagnostics/data/memory_monitor_store.dart' as _i193;
import '../../features/geo/cubit/geo_cubit.dart' as _i818;
import '../../features/geo/data/geo_config_gate.dart' as _i951;
import '../../features/geo/data/geo_paths.dart' as _i262;
import '../../features/geo/data/geo_repository.dart' as _i236;
import '../../features/geo/data/geo_update_service.dart' as _i196;
import '../../features/ping/data/host_resolver.dart' as _i371;
import '../../features/ping/data/ping_settings_store.dart' as _i384;
import '../../features/ping/data/ping_target_resolver.dart' as _i142;
import '../../features/ping/data/quic_probe_pinger.dart' as _i874;
import '../../features/ping/data/tcp_connect_pinger.dart' as _i970;
import '../../features/ping/domain/contracts/host_resolver.dart' as _i139;
import '../../features/ping/domain/contracts/server_pinger.dart' as _i437;
import '../../features/ping/domain/usecases/measure_ping_use_case.dart'
    as _i283;
import '../../features/ping/presentation/ping_auto_runner.dart' as _i918;
import '../../features/ping/presentation/ping_cubit.dart' as _i629;
import '../../features/qr/data/qr_image_import.dart' as _i543;
import '../../features/qr/data/qr_share_service.dart' as _i698;
import '../../features/routing/cubit/ad_block_cubit.dart' as _i863;
import '../../features/routing/cubit/ru_bypass_cubit.dart' as _i1048;
import '../../features/routing/data/ad_block_store.dart' as _i117;
import '../../features/routing/data/local_proxy_client.dart' as _i864;
import '../../features/routing/data/routing_policy_gate.dart' as _i194;
import '../../features/routing/data/ru_bypass_store.dart' as _i310;
import '../../features/split_tunnel/cubit/installed_apps_cubit.dart' as _i998;
import '../../features/split_tunnel/cubit/split_tunnel_cubit.dart' as _i277;
import '../../features/split_tunnel/data/installed_apps_api.g.dart' as _i999;
import '../../features/split_tunnel/data/installed_apps_repository.dart'
    as _i315;
import '../../features/split_tunnel/data/split_tunnel_store.dart' as _i43;
import '../../features/subscriptions/cubit/subscription_auto_update_cubit.dart'
    as _i3;
import '../../features/subscriptions/cubit/subscription_auto_updater.dart'
    as _i706;
import '../../features/subscriptions/cubit/subscriptions_cubit.dart' as _i83;
import '../../features/subscriptions/data/auto_update/background_sync_scheduler.dart'
    as _i694;
import '../../features/subscriptions/data/auto_update/subscription_sync_job.dart'
    as _i474;
import '../../features/subscriptions/data/auto_update/subscription_update_settings_store.dart'
    as _i331;
import '../../features/subscriptions/data/selected_server_store.dart' as _i830;
import '../../features/subscriptions/data/subscription_description_store.dart'
    as _i811;
import '../../features/subscriptions/data/subscription_factory.dart' as _i179;
import '../../features/subscriptions/data/subscription_parser/subscription_fetcher.dart'
    as _i746;
import '../../features/subscriptions/data/subscription_parser/subscription_parser_service.dart'
    as _i302;
import '../../features/subscriptions/data/subscription_refresher.dart' as _i944;
import '../../features/subscriptions/data/subscription_storage/subscription_storage.dart'
    as _i505;
import '../../features/update/data/update_repository.dart' as _i11;
import '../../features/update/data/updater_api.g.dart' as _i942;
import '../../features/vpn/data/vpn_api.g.dart' as _i482;
import '../../features/vpn/data/vpn_event_receiver.dart' as _i924;
import '../../features/vpn/data/vpn_repository.dart' as _i1056;
import '../../features/vpn/data/vpn_session_store.dart' as _i871;
import '../../features/vpn/data/xray_log_store.dart' as _i490;
import 'device_module.dart' as _i782;
import 'installed_apps_module.dart' as _i394;
import 'logger_module.dart' as _i987;
import 'prefs_module.dart' as _i891;
import 'storage_module.dart' as _i372;
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
    final deviceModule = _$DeviceModule();
    final installedAppsModule = _$InstalledAppsModule();
    final loggerModule = _$LoggerModule();
    final updaterModule = _$UpdaterModule();
    final vpnModule = _$VpnModule();
    final storageModule = _$StorageModule();
    await gh.singletonAsync<_i460.SharedPreferences>(
      () => prefsModule.prefs,
      preResolve: true,
    );
    gh.lazySingleton<_i1033.DeviceInfoApi>(() => deviceModule.deviceInfoApi);
    gh.lazySingleton<_i999.InstalledAppsApi>(
      () => installedAppsModule.installedAppsApi,
    );
    gh.lazySingleton<_i207.Talker>(() => loggerModule.talker);
    gh.lazySingleton<_i942.UpdateInstaller>(
      () => updaterModule.updateInstaller,
    );
    gh.lazySingleton<_i482.VpnConnection>(() => vpnModule.vpnConnection);
    gh.lazySingleton<_i924.NativeVpnEventReceiver>(
      () => vpnModule.vpnEventReceiver,
    );
    gh.lazySingleton<_i142.PingTargetResolver>(
      () => const _i142.PingTargetResolver(),
    );
    gh.lazySingleton<_i543.QrImageImporter>(() => _i543.QrImageImporter());
    gh.lazySingleton<_i698.QrShareService>(() => _i698.QrShareService());
    gh.lazySingleton<_i179.SubscriptionFactory>(
      () => _i179.SubscriptionFactory(),
    );
    gh.lazySingleton<_i490.XrayLogStore>(
      () => _i490.XrayLogStore(),
      dispose: (i) => i.dispose(),
    );
    gh.lazySingleton<_i315.InstalledAppsRepository>(
      () => _i315.InstalledAppsRepository(
        gh<_i999.InstalledAppsApi>(),
        gh<_i207.Talker>(),
      ),
    );
    gh.lazySingleton<_i437.ServerPinger>(
      () => _i970.TcpConnectPinger(),
      instanceName: 'tcp',
    );
    gh.lazySingleton<_i437.ServerPinger>(
      () => _i874.QuicProbePinger(),
      instanceName: 'quic',
    );
    gh.factory<_i998.InstalledAppsCubit>(
      () => _i998.InstalledAppsCubit(gh<_i315.InstalledAppsRepository>()),
    );
    gh.lazySingleton<_i694.BackgroundSyncScheduler>(
      () => _i694.PlatformBackgroundSyncScheduler(gh<_i207.Talker>()),
    );
    gh.lazySingleton<_i951.GeoConfigGate>(
      () => _i951.GeoConfigGate(gh<_i207.Talker>()),
    );
    gh.lazySingleton<_i194.RoutingPolicyGate>(
      () => _i194.RoutingPolicyGate(gh<_i207.Talker>()),
    );
    await gh.singletonAsync<_i505.SubscriptionStorage>(
      () => storageModule.subscriptionStorage(gh<_i207.Talker>()),
      preResolve: true,
    );
    await gh.singletonAsync<_i497.Directory>(
      () => updaterModule.updatesDir,
      instanceName: 'updatesDir',
      preResolve: true,
    );
    gh.lazySingleton<_i139.HostResolver>(() => const _i371.DnsHostResolver());
    gh.lazySingleton<_i802.ThemeStore>(
      () => _i802.ThemeStore(gh<_i460.SharedPreferences>()),
    );
    gh.lazySingleton<_i979.HomeLayoutStore>(
      () => _i979.HomeLayoutStore(gh<_i460.SharedPreferences>()),
    );
    gh.lazySingleton<_i407.ClientIdentityStore>(
      () => _i407.ClientIdentityStore(gh<_i460.SharedPreferences>()),
    );
    gh.lazySingleton<_i193.MemoryMonitorStore>(
      () => _i193.MemoryMonitorStore(gh<_i460.SharedPreferences>()),
    );
    gh.lazySingleton<_i384.PingSettingsStore>(
      () => _i384.PingSettingsStore(gh<_i460.SharedPreferences>()),
    );
    gh.lazySingleton<_i117.AdBlockStore>(
      () => _i117.AdBlockStore(gh<_i460.SharedPreferences>()),
    );
    gh.lazySingleton<_i310.RuBypassStore>(
      () => _i310.RuBypassStore(gh<_i460.SharedPreferences>()),
    );
    gh.lazySingleton<_i43.SplitTunnelStore>(
      () => _i43.SplitTunnelStore(gh<_i460.SharedPreferences>()),
    );
    gh.lazySingleton<_i331.SubscriptionUpdateSettingsStore>(
      () =>
          _i331.SubscriptionUpdateSettingsStore(gh<_i460.SharedPreferences>()),
    );
    gh.lazySingleton<_i830.SelectedServerStore>(
      () => _i830.SelectedServerStore(gh<_i460.SharedPreferences>()),
    );
    gh.lazySingleton<_i811.SubscriptionDescriptionStore>(
      () => _i811.SubscriptionDescriptionStore(gh<_i460.SharedPreferences>()),
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
    gh.lazySingleton<_i864.LocalProxyProvider>(
      () => _i864.LocalProxyProvider(
        gh<_i482.VpnConnection>(),
        gh<_i207.Talker>(),
      ),
    );
    gh.lazySingleton<_i283.MeasurePingUseCase>(
      () => _i283.MeasurePingUseCase(
        gh<_i437.ServerPinger>(instanceName: 'tcp'),
        gh<_i437.ServerPinger>(instanceName: 'quic'),
        gh<_i139.HostResolver>(),
      ),
    );
    gh.lazySingleton<_i628.MemoryMonitorCubit>(
      () => _i628.MemoryMonitorCubit(store: gh<_i193.MemoryMonitorStore>()),
    );
    gh.lazySingleton<_i11.UpdateRepository>(
      () => _i11.UpdateRepository(
        gh<_i207.Talker>(),
        gh<_i942.UpdateInstaller>(),
        gh<_i497.Directory>(instanceName: 'updatesDir'),
      ),
      dispose: (i) => i.dispose(),
    );
    gh.lazySingleton<_i12.AppThemeCubit>(
      () => _i12.AppThemeCubit(themeStore: gh<_i802.ThemeStore>()),
    );
    gh.lazySingleton<_i304.HomeLayoutCubit>(
      () => _i304.HomeLayoutCubit(store: gh<_i979.HomeLayoutStore>()),
    );
    gh.lazySingleton<_i1021.UpdateServiceCubit>(
      () => _i1021.UpdateServiceCubit(
        repository: gh<_i11.UpdateRepository>(),
        talker: gh<_i207.Talker>(),
      ),
    );
    gh.lazySingleton<_i277.SplitTunnelCubit>(
      () => _i277.SplitTunnelCubit(store: gh<_i43.SplitTunnelStore>()),
    );
    gh.lazySingleton<_i568.ClientIdentityRepository>(
      () => _i568.ClientIdentityRepository(
        gh<_i407.ClientIdentityStore>(),
        gh<_i1033.DeviceInfoApi>(),
        gh<_i207.Talker>(),
      ),
    );
    gh.lazySingleton<_i236.GeoRepository>(
      () => _i236.GeoRepository(
        gh<_i262.GeoPaths>(),
        gh<_i207.Talker>(),
        gh<_i864.LocalProxyProvider>(),
      ),
      dispose: (i) => i.dispose(),
    );
    gh.lazySingleton<_i1048.RuBypassCubit>(
      () => _i1048.RuBypassCubit(store: gh<_i310.RuBypassStore>()),
    );
    gh.lazySingleton<_i629.PingCubit>(
      () => _i629.PingCubit(
        gh<_i283.MeasurePingUseCase>(),
        gh<_i142.PingTargetResolver>(),
        gh<_i384.PingSettingsStore>(),
      ),
    );
    gh.lazySingleton<_i962.AppColors>(
      () => _i962.AppColors(themeCubit: gh<_i12.AppThemeCubit>()),
    );
    gh.lazySingleton<_i746.SubscriptionFetcher>(
      () => _i746.SubscriptionFetcher(
        gh<_i568.ClientIdentityRepository>(),
        gh<_i864.LocalProxyProvider>(),
      ),
    );
    gh.lazySingleton<_i818.GeoCubit>(
      () => _i818.GeoCubit(
        repository: gh<_i236.GeoRepository>(),
        talker: gh<_i207.Talker>(),
      ),
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
        gh<_i194.RoutingPolicyGate>(),
        gh<_i1048.RuBypassCubit>(),
        gh<_i863.AdBlockCubit>(),
        gh<_i277.SplitTunnelCubit>(),
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
    gh.lazySingleton<_i302.SubscriptionParserService>(
      () => _i302.SubscriptionParserService(
        gh<_i207.Talker>(),
        gh<_i746.SubscriptionFetcher>(),
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
    gh.lazySingleton<_i190.MemoryUsageCubit>(
      () => _i190.MemoryUsageCubit(repository: gh<_i1056.VpnRepository>()),
    );
    gh.lazySingleton<_i944.SubscriptionRefresher>(
      () => _i944.SubscriptionRefresher(
        gh<_i302.SubscriptionParserService>(),
        gh<_i179.SubscriptionFactory>(),
      ),
    );
    gh.lazySingleton<_i83.SubscriptionsCubit>(
      () => _i83.SubscriptionsCubit(
        parser: gh<_i302.SubscriptionParserService>(),
        storage: gh<_i505.SubscriptionStorage>(),
        selectedServerStore: gh<_i830.SelectedServerStore>(),
        factory: gh<_i179.SubscriptionFactory>(),
        refresher: gh<_i944.SubscriptionRefresher>(),
        vpnServiceCubit: gh<_i202.VpnServiceCubit>(),
        talker: gh<_i207.Talker>(),
      ),
    );
    gh.lazySingleton<_i474.SubscriptionSyncJob>(
      () => _i474.SubscriptionSyncJob(
        gh<_i505.SubscriptionStorage>(),
        gh<_i944.SubscriptionRefresher>(),
        gh<_i331.SubscriptionUpdateSettingsStore>(),
        gh<_i207.Talker>(),
      ),
    );
    gh.lazySingleton<_i918.PingAutoRunner>(
      () => _i918.PingAutoRunner(
        gh<_i629.PingCubit>(),
        gh<_i384.PingSettingsStore>(),
        gh<_i83.SubscriptionsCubit>(),
      ),
    );
    gh.lazySingleton<_i706.SubscriptionAutoUpdater>(
      () => _i706.SubscriptionAutoUpdater(
        gh<_i83.SubscriptionsCubit>(),
        gh<_i331.SubscriptionUpdateSettingsStore>(),
        gh<_i202.VpnServiceCubit>(),
        gh<_i694.BackgroundSyncScheduler>(),
        gh<_i207.Talker>(),
      ),
      dispose: (i) => i.dispose(),
    );
    gh.lazySingleton<_i3.SubscriptionAutoUpdateCubit>(
      () => _i3.SubscriptionAutoUpdateCubit(
        gh<_i331.SubscriptionUpdateSettingsStore>(),
        gh<_i706.SubscriptionAutoUpdater>(),
      ),
    );
    return this;
  }
}

class _$PrefsModule extends _i891.PrefsModule {}

class _$DeviceModule extends _i782.DeviceModule {}

class _$InstalledAppsModule extends _i394.InstalledAppsModule {}

class _$LoggerModule extends _i987.LoggerModule {}

class _$UpdaterModule extends _i884.UpdaterModule {}

class _$VpnModule extends _i731.VpnModule {}

class _$StorageModule extends _i372.StorageModule {}
