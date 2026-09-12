part of 'geo_cubit.dart';

@freezed
abstract class GeoState with _$GeoState {
  const GeoState._();

  /// No usable geo data on disk.
  const factory GeoState.absent() = GeoAbsent;

  /// Talking to GitHub about the latest release.
  const factory GeoState.checking() = GeoChecking;

  const factory GeoState.downloading({
    required double fraction,
    required int received,
    required int total,
  }) = GeoDownloading;

  /// Installed and up to date (or update status unknown).
  const factory GeoState.ready({
    required GeoCatalog catalog,
    required String tag,
    required DateTime updatedAt,
  }) = GeoReady;

  /// Installed, but a newer release exists.
  const factory GeoState.updateAvailable({
    required GeoCatalog catalog,
    required String tag,
    required DateTime updatedAt,
    required String latestTag,
  }) = GeoUpdateAvailable;

  const factory GeoState.failed(String message) = GeoFailed;

  /// The categories the connect-time gate may keep. Empty unless geo is
  /// actually installed.
  GeoCatalog get catalog => switch (this) {
    GeoReady(:final catalog) => catalog,
    GeoUpdateAvailable(:final catalog) => catalog,
    _ => const GeoCatalog.empty(),
  };

  bool get isReady => this is GeoReady || this is GeoUpdateAvailable;
}
