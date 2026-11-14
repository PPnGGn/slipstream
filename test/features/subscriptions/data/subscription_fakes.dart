import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream/core/models/result.dart';
import 'package:slipstream/core/models/stored_subscription/stored_subscription.dart';
import 'package:slipstream/core/models/vpn_server/vpn_server.dart';
import 'package:slipstream/core/service/vpn_service/vpn_service_cubit.dart';
import 'package:slipstream/core/models/subscription/subscription.dart';
import 'package:slipstream/features/notifications/data/app_alerts.dart';
import 'package:slipstream/features/subscriptions/data/subscription_limit_alerter.dart';
import 'package:slipstream/features/subscriptions/data/auto_update/background_sync_scheduler.dart';
import 'package:slipstream/features/subscriptions/data/subscription_parser/subscription_parser_service.dart';
import 'package:slipstream/features/subscriptions/data/subscription_storage/subscription_storage.dart';

/// A VPN cubit whose state the test drives with [push].
class FakeVpnCubit extends Fake implements VpnServiceCubit {
  final _controller = StreamController<VpnState>.broadcast();
  VpnState _state = const VpnState.disconnected();
  final switched = <VpnServer>[];

  @override
  VpnState get state => _state;

  @override
  Stream<VpnState> get stream => _controller.stream;

  void push(VpnState state) {
    _state = state;
    _controller.add(state);
  }

  @override
  void switchServerIfActive(VpnServer server) => switched.add(server);
}

/// Records every enable/disable request.
class FakeBackgroundSync implements BackgroundSyncScheduler {
  final calls = <bool>[];

  @override
  Future<void> setEnabled(bool enabled) async => calls.add(enabled);
}

/// Records the alerts that would have been shown or taken back.
class RecordingAppAlerts implements AppAlerts {
  final shown = <({AppAlertKind kind, String name, int? number})>[];
  final cancelled = <(AppAlertKind, String)>[];

  @override
  Future<void> show(
    AppAlertKind kind, {
    required String subscriptionName,
    int? number,
  }) async => shown.add((kind: kind, name: subscriptionName, number: number));

  @override
  Future<void> cancel(AppAlertKind kind, String subscriptionName) async =>
      cancelled.add((kind, subscriptionName));
}

/// Stands for the alerter about time and traffic: records the subscriptions it
/// was asked about and, when [marks] is set, puts those marks on them.
class FakeLimitAlerter extends Fake implements SubscriptionLimitAlerter {
  final applied = <String>[];
  final forgotten = <String>[];
  List<String> marks = const [];

  @override
  Future<void> forget(Subscription sub) async => forgotten.add(sub.id);

  @override
  Future<Subscription> apply(Subscription sub) async {
    applied.add(sub.id);
    return marks.isEmpty ? sub : sub.copyWith(notifiedAlerts: marks);
  }
}

/// A parser that answers with [_answer] and records every input.
class FakeParser extends Fake implements SubscriptionParserService {
  FakeParser(this._answer);

  final Future<Result<ParsedSubscription>> Function(String input) _answer;
  final inputs = <String>[];

  @override
  Future<Result<ParsedSubscription>> parseFromInput(String input) {
    inputs.add(input);
    return _answer(input);
  }
}

/// Keeps subscriptions in a map, in insertion order.
class InMemoryStorage implements SubscriptionStorage {
  InMemoryStorage([Iterable<StoredSubscription> initial = const []]) {
    for (final s in initial) {
      items[s.subscription.id] = s;
    }
  }

  final items = <String, StoredSubscription>{};
  final saved = <String>[];

  @override
  Future<List<StoredSubscription>> loadAll() async => items.values.toList();

  @override
  Future<void> save(StoredSubscription subscription) async {
    saved.add(subscription.subscription.id);
    items[subscription.subscription.id] = subscription;
  }

  @override
  Future<void> delete(String subscriptionId) async =>
      items.remove(subscriptionId);

  @override
  Future<bool> exists(String subscriptionId) async =>
      items.containsKey(subscriptionId);
}
