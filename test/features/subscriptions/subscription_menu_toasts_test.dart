import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream/core/models/stored_subscription/stored_subscription.dart';
import 'package:slipstream/core/models/subscription/subscription.dart';
import 'package:slipstream/core/models/vpn_server/vpn_server.dart';
import 'package:slipstream/core/service/toast/toast_message.dart';
import 'package:slipstream/features/subscriptions/cubit/refresh_outcome.dart';
import 'package:slipstream/features/subscriptions/data/subscription_parser/subscription_exceptions.dart';
import 'package:slipstream/features/subscriptions/ui/subscription_menu_toasts.dart';

StoredSubscription _stored(String name, int servers) => StoredSubscription(
  subscription: Subscription(
    id: 'sub',
    url: 'https://example.com/sub',
    name: name,
    lastUpdatedAt: DateTime(2026),
  ),
  servers: [
    for (var i = 0; i < servers; i++)
      VpnServer(
        id: 's$i',
        subscriptionId: 'sub',
        countryCode: 'NL',
        title: 'S$i',
        configJson: '{}',
      ),
  ],
);

void main() {
  group('refreshToast', () {
    test('a refreshed subscription counts its servers and names itself', () {
      expect(
        refreshToast(Refreshed(_stored('Nebula Premium', 12))),
        const ToastSpec(
          'Subscription updated',
          subtitle: '12 SERVERS · NEBULA PREMIUM',
        ),
      );
    });

    test('says "server" for exactly one', () {
      expect(
        refreshToast(Refreshed(_stored('Home', 1)))!.subtitle,
        '1 SERVER · HOME',
      );
    });

    test('a failure explains itself in plain words', () {
      expect(
        refreshToast(const RefreshFailed(HttpStatusException(404))),
        const ToastSpec(
          'Link not found',
          subtitle: 'CHECK THE LINK',
          kind: ToastKind.error,
        ),
      );
      expect(
        refreshToast(RefreshFailed(TimeoutException('slow'))),
        const ToastSpec(
          "Server didn't respond",
          subtitle: 'CHECK CONNECTION · TRY AGAIN',
          kind: ToastKind.error,
        ),
      );
    });

    test('an unknown failure says "update", not "add"', () {
      expect(
        refreshToast(const RefreshFailed(FormatException('boom'))),
        const ToastSpec(
          "Couldn't update subscription",
          subtitle: 'SEE APP LOGS FOR DETAILS',
          kind: ToastKind.error,
        ),
      );
    });

    test('an ignored refresh says nothing', () {
      expect(refreshToast(const RefreshIgnored()), isNull);
    });
  });

  group('refreshAllToast', () {
    test('nothing fetched says nothing', () {
      expect(refreshAllToast(const []), isNull);
      expect(refreshAllToast(const [RefreshIgnored()]), isNull);
    });

    test('a single subscription reads like the menu refresh', () {
      final outcome = Refreshed(_stored('Home', 3));
      expect(
        refreshAllToast([outcome, const RefreshIgnored()]),
        refreshToast(outcome),
      );
      expect(
        refreshAllToast(const [RefreshFailed(HttpStatusException(404))]),
        refreshToast(const RefreshFailed(HttpStatusException(404))),
      );
    });

    test('several updated count subscriptions and servers', () {
      expect(
        refreshAllToast([
          Refreshed(_stored('A', 12)),
          Refreshed(_stored('B', 1)),
        ]),
        const ToastSpec(
          'Subscriptions updated',
          subtitle: '2 SUBSCRIPTIONS · 13 SERVERS',
        ),
      );
    });

    test('a failure among several says how many failed', () {
      expect(
        refreshAllToast([
          Refreshed(_stored('A', 12)),
          const RefreshFailed(HttpStatusException(502)),
          const RefreshIgnored(),
          RefreshFailed(TimeoutException('slow')),
        ]),
        const ToastSpec(
          "Couldn't update 2 of 3",
          subtitle: 'MARKED IN THE LIST',
          kind: ToastKind.error,
        ),
      );
    });
  });

  test('a deleted subscription is named in caps', () {
    expect(
      subscriptionDeletedToast('Nebula Premium'),
      const ToastSpec(
        'Subscription deleted',
        subtitle: 'NEBULA PREMIUM',
      ),
    );
  });
}
