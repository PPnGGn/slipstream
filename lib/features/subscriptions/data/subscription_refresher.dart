import 'package:injectable/injectable.dart';
import 'package:slipstream/core/models/result.dart';
import 'package:slipstream/core/models/stored_subscription/stored_subscription.dart';
import 'package:slipstream/features/subscriptions/data/subscription_factory.dart';
import 'package:slipstream/features/subscriptions/data/subscription_parser/subscription_parser_service.dart';

/// Re-fetches one URL subscription. Shared by the UI (manual and automatic
/// refresh) and the background job, so it never saves anything itself: the
/// caller owns the storage and decides whether the result still applies.
@lazySingleton
class SubscriptionRefresher {
  SubscriptionRefresher(
    this._parser,
    this._factory, {
    @ignoreParam DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final SubscriptionParserService _parser;
  final SubscriptionFactory _factory;
  final DateTime Function() _now;

  /// The refreshed subscription. A failure is not thrown: it comes back as
  /// the same servers with `lastError` and `lastAttemptAt` set, so the
  /// schedule can back off and the list can show it.
  Future<StoredSubscription> refresh(StoredSubscription stored) async {
    final url = stored.subscription.url;
    if (url == null) return stored;

    final result = await _parser.parseFromInput(url);
    final now = _now();
    return switch (result) {
      Success(:final data) => _factory.refresh(stored, data, at: now),
      Failure(:final message) => stored.copyWith(
        subscription: stored.subscription.copyWith(
          lastAttemptAt: now,
          lastError: message,
        ),
      ),
    };
  }
}
