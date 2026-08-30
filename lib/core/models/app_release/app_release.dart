import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_release.freezed.dart';

@freezed
abstract class AppRelease with _$AppRelease {
  const factory AppRelease({
    required String version,
    required int buildNumber,
    required String tagName,
    required String downloadUrl,
    required int sizeBytes,
    String? notes,
  }) = _AppRelease;
}
