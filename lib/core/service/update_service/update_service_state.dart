part of 'update_service_cubit.dart';

@freezed
abstract class UpdateState with _$UpdateState {
  const factory UpdateState.idle() = _Idle;
  const factory UpdateState.checking() = _Checking;
  const factory UpdateState.upToDate() = _UpToDate;
  const factory UpdateState.downloading(
    AppRelease release, {
    required int receivedBytes,
  }) = _Downloading;
  const factory UpdateState.readyToInstall(
    AppRelease release,
    String filePath,
  ) = _ReadyToInstall;
  const factory UpdateState.error(String message) = _Error;
}
