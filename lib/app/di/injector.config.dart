// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:get_it/get_it.dart' as _i174;
import 'package:injectable/injectable.dart' as _i526;
import 'package:shared_preferences/shared_preferences.dart' as _i460;
import 'package:talker_flutter/talker_flutter.dart' as _i207;

import '../../core/service/vpn_service/vpn_service_cubit.dart' as _i13;
import '../../core/theme/app_colors.dart' as _i962;
import '../../core/theme/cubit/theme_cubit.dart' as _i11;
import '../../features/subscriptions/cubit/subscriptions_cubit.dart' as _i83;
import '../../features/subscriptions/data/selected_server_store.dart' as _i830;
import '../../features/subscriptions/data/subscription_factory.dart' as _i179;
import '../../features/subscriptions/data/subscription_parser/subscription_parser_service.dart'
    as _i302;
import '../../features/subscriptions/data/subscription_storage/subscription_storage.dart'
    as _i505;
import '../../features/vpn/data/vpn_api.g.dart' as _i482;
import '../../features/vpn/data/vpn_event_receiver.dart' as _i924;
import '../../features/vpn/data/vpn_repository.dart' as _i1056;
import '../../features/vpn/data/vpn_session_store.dart' as _i871;
import '../../features/vpn/data/xray_log_store.dart' as _i490;
import 'logger_module.dart' as _i987;
import 'prefs_module.dart' as _i891;
import 'storage_module.dart' as _i371;
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
    final vpnModule = _$VpnModule();
    final storageModule = _$StorageModule();
    await gh.singletonAsync<_i460.SharedPreferences>(
      () => prefsModule.prefs,
      preResolve: true,
    );
    gh.lazySingleton<_i207.Talker>(() => loggerModule.talker);
    gh.lazySingleton<_i482.VpnConnection>(() => vpnModule.vpnConnection);
    gh.lazySingleton<_i924.NativeVpnEventReceiver>(
      () => vpnModule.vpnEventReceiver,
    );
    gh.lazySingleton<_i11.AppThemeCubit>(() => _i11.AppThemeCubit());
    gh.lazySingleton<_i179.SubscriptionFactory>(
      () => _i179.SubscriptionFactory(),
    );
    gh.lazySingleton<_i490.XrayLogStore>(
      () => _i490.XrayLogStore(),
      dispose: (i) => i.dispose(),
    );
    await gh.singletonAsync<_i505.SubscriptionStorage>(
      () => storageModule.subscriptionStorage(gh<_i207.Talker>()),
      preResolve: true,
    );
    gh.lazySingleton<_i302.SubscriptionParserService>(
      () => _i302.SubscriptionParserService(gh<_i207.Talker>()),
    );
    gh.lazySingleton<_i830.SelectedServerStore>(
      () => _i830.SelectedServerStore(gh<_i460.SharedPreferences>()),
    );
    gh.lazySingleton<_i871.VpnSessionStore>(
      () => _i871.VpnSessionStore(gh<_i460.SharedPreferences>()),
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
      ),
      dispose: (i) => i.dispose(),
    );
    gh.lazySingleton<_i13.VpnServiceCubit>(
      () => _i13.VpnServiceCubit(
        repository: gh<_i1056.VpnRepository>(),
        sessionStore: gh<_i871.VpnSessionStore>(),
        talker: gh<_i207.Talker>(),
      ),
    );
    gh.lazySingleton<_i83.SubscriptionsCubit>(
      () => _i83.SubscriptionsCubit(
        parser: gh<_i302.SubscriptionParserService>(),
        storage: gh<_i505.SubscriptionStorage>(),
        selectedServerStore: gh<_i830.SelectedServerStore>(),
        factory: gh<_i179.SubscriptionFactory>(),
        talker: gh<_i207.Talker>(),
      ),
    );
    return this;
  }
}

class _$PrefsModule extends _i891.PrefsModule {}

class _$LoggerModule extends _i987.LoggerModule {}

class _$VpnModule extends _i731.VpnModule {}

class _$StorageModule extends _i371.StorageModule {}
