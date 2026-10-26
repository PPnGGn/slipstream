part of 'installed_apps_cubit.dart';

@freezed
abstract class InstalledAppsState with _$InstalledAppsState {
  const factory InstalledAppsState.loading() = InstalledAppsLoading;

  const factory InstalledAppsState.loaded(
    List<InstalledAppMessage> apps, {
    @Default('') String query,
  }) = InstalledAppsLoaded;

  const factory InstalledAppsState.failed(String message) = InstalledAppsFailed;
}
