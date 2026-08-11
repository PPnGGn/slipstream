import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:slipstream/core/models/subscription/subscription.dart';
import 'package:slipstream/core/models/vpn_server/vpn_server.dart';

part 'stored_subscription.freezed.dart';
part 'stored_subscription.g.dart';

@freezed
abstract class StoredSubscription with _$StoredSubscription {
  const factory StoredSubscription({
    required Subscription subscription,
    required List<VpnServer> servers,
  }) = _StoredSubscription;

  factory StoredSubscription.fromJson(Map<String, dynamic> json) =>
      _$StoredSubscriptionFromJson(json);
}
