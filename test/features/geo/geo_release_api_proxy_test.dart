import 'package:flutter_test/flutter_test.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:slipstream/features/geo/data/geo_release_api.dart';
import 'package:slipstream/features/routing/data/local_proxy_client.dart';
import 'package:slipstream/features/subscriptions/data/subscription_parser/subscription_fetcher.dart';

import '../../helpers/fake_unix_proxy.dart';
import '../client_identity/fakes.dart';

/// The password of the core's proxy is new in every session. A request that is
/// made right at a restart of the core (the user picks another server while
/// connected) can be sent with the password of the session that is ending.
/// These two make their requests through the proxy with a client that asks the
/// core for the current password and sends the request again once, when it was
/// not the one it used: the geo release check and the fallback of the
/// subscription fetcher.
void main() {
  late FakeUnixProxy fake;

  setUp(() async {
    // The CONNECT of an HTTPS request is answered with 502 once the password is
    // right, so the request itself ends in an error; what the test looks at is
    // how many times it went, and with which password.
    fake = await FakeUnixProxy.start(
      answer: 'HTTP/1.1 502 Bad Gateway\r\nContent-Length: 0\r\n\r\n',
    );
  });
  tearDown(() => fake.close());

  test('the geo release check goes again with the new password', () async {
    // The core reports p1 when the client is built, then restarts with p2.
    var reported = 'p1';
    final provider = LocalProxyProvider(
      FakeVpnConnection(() async {
        final message = fake.message(reported);
        // The restart happens while the request is on its way: from the second
        // question on, the core says p2, and so does the proxy.
        reported = 'p2';
        fake.pass = 'p2';
        return message;
      }),
      Talker(),
    );

    await expectLater(
      GeoReleaseApi(proxy: provider).fetchLatest(),
      throwsA(anything), // the 502 of the fake
    );

    expect(fake.authorized, [false, true]);
  });

  test('the subscription fetch through the tunnel does the same', () async {
    var reported = 'p1';
    final provider = LocalProxyProvider(
      FakeVpnConnection(() async {
        final message = fake.message(reported);
        reported = 'p2';
        fake.pass = 'p2';
        return message;
      }),
      Talker(),
    );
    final fetcher = SubscriptionFetcher(
      await identityRepositoryWith(FakeDeviceInfoApi(deviceId: 'abc')),
      provider,
    );

    // The direct request to a host that does not exist fails at once (a network
    // error), which is what sends the fetcher to the tunnel.
    await expectLater(
      fetcher.fetch('https://subscription.invalid/sub'),
      throwsA(anything), // the 502 of the fake
    );

    expect(fake.authorized, [false, true]);
  });
}
