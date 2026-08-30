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
  }) = _Subscription;

  factory Subscription.fromJson(Map<String, dynamic> json) =>
      _$SubscriptionFromJson(json);
}
