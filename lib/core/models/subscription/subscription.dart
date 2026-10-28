import 'package:freezed_annotation/freezed_annotation.dart';

part 'subscription.freezed.dart';
part 'subscription.g.dart';

@freezed
abstract class Subscription with _$Subscription {
  const factory Subscription({
    required String id,
    required String? url,
    required String name,
    required DateTime lastUpdatedAt,
    String? announce,
    DateTime? expiresAt,
    int? updateIntervalHours,
    int? usedBytes,
    int? dataLimitBytes,

    /// When the last refresh attempt finished, successful or not.
    DateTime? lastAttemptAt,

    /// Why the last refresh attempt failed; null after a successful one.
    String? lastError,

    /// Ids of the servers the user pinned. Kept here, not on the servers: a
    /// refresh replaces them all, and the subscription stays (the factory
    /// carries the ids over, see `remapFavoriteIds`).
    @Default(<String>[]) List<String> favoriteServerIds,
  }) = _Subscription;

  factory Subscription.fromJson(Map<String, dynamic> json) =>
      _$SubscriptionFromJson(json);
}
