import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:slipstream/core/service/toast/toast_message.dart';
import 'package:slipstream/features/subscriptions/data/subscription_parser/subscription_exceptions.dart';
import 'package:slipstream/features/subscriptions/data/subscription_parser/subscription_fetcher.dart';
import 'package:slipstream/features/subscriptions/ui/add_subscription_toasts.dart';

void main() {
  test('adding nothing asks to paste a link or key first', () {
    expect(
      nothingToAddToast,
      const ToastSpec(
        'Nothing to add',
        subtitle: 'PASTE A LINK OR KEY FIRST',
        kind: ToastKind.error,
      ),
    );
  });

  test('an empty clipboard asks to copy something first', () {
    expect(
      emptyClipboardToast,
      const ToastSpec(
        'Clipboard is empty',
        subtitle: 'COPY A LINK OR KEY FIRST',
        kind: ToastKind.error,
      ),
    );
  });

  test('a picture without a QR code suggests another picture', () {
    expect(
      noQrInImageToast,
      const ToastSpec(
        'No QR code found',
        subtitle: 'TRY ANOTHER IMAGE',
        kind: ToastKind.error,
      ),
    );
  });

  group('addFailedToast says it in plain words', () {
    ToastSpec error(String title, String subtitle) =>
        ToastSpec(title, subtitle: subtitle, kind: ToastKind.error);

    test('text that is not a link or a key', () {
      expect(
        addFailedToast(const InvalidInputFormatException()),
        error('Invalid key or link', 'CHECK THAT IT IS COPIED IN FULL'),
      );
    });

    test('a link with nothing the app supports', () {
      expect(
        addFailedToast(const NoServersFoundException()),
        error('No servers found', 'NOTHING IN IT THE APP SUPPORTS'),
      );
    });

    test('a subscription that is already in the list', () {
      expect(
        addFailedToast(const DuplicateSubscriptionException()),
        error('Already added', 'THIS SUBSCRIPTION IS IN YOUR LIST'),
      );
    });

    test('the provider limits the number of devices', () {
      expect(
        addFailedToast(const DeviceLimitReachedException()),
        error('Device limit reached', 'ASK THE PROVIDER TO REMOVE AN OLD DEVICE'),
      );
      expect(
        addFailedToast(const HwidRequiredException()),
        error('Provider rejected this device', 'TRY LATER OR CONTACT THE PROVIDER'),
      );
    });

    test('an access error means the link is no longer valid', () {
      for (final code in [401, 403]) {
        expect(
          addFailedToast(HttpStatusException(code)),
          error('Access denied', 'THE LINK MAY BE EXPIRED OR REVOKED'),
          reason: '$code',
        );
      }
    });

    test('a missing link', () {
      expect(
        addFailedToast(const HttpStatusException(404)),
        error('Link not found', 'CHECK THE LINK'),
      );
    });

    test('too many requests', () {
      expect(
        addFailedToast(const HttpStatusException(429)),
        error('Too many requests', 'WAIT A MINUTE AND TRY AGAIN'),
      );
    });

    test('a server error on the provider side shows the code', () {
      expect(
        addFailedToast(const HttpStatusException(502)),
        error('Provider server error', 'TRY AGAIN LATER · HTTP 502'),
      );
    });

    test('any other status shows the code too', () {
      expect(
        addFailedToast(const HttpStatusException(418)),
        error('Provider refused the link', 'HTTP 418'),
      );
    });

    test('no answer in time', () {
      expect(
        addFailedToast(TimeoutException('slow')),
        error("Server didn't respond", 'CHECK CONNECTION · TRY AGAIN'),
      );
    });

    test('the server cannot be reached at all', () {
      for (final cause in [
        const SocketException('unreachable'),
        const HandshakeException('cut'),
        http.ClientException('reset'),
      ]) {
        expect(
          addFailedToast(cause),
          error("Can't reach the server", 'CHECK CONNECTION · TRY AGAIN'),
          reason: '${cause.runtimeType}',
        );
      }
    });

    test('anything unexpected stays generic and points to the logs', () {
      expect(
        addFailedToast(const FormatException('boom')),
        error("Couldn't add subscription", 'SEE APP LOGS FOR DETAILS'),
      );
      expect(
        addFailedToast(null),
        error("Couldn't add subscription", 'SEE APP LOGS FOR DETAILS'),
      );
    });
  });

  group('subscriptionAddedToast', () {
    test('counts the servers and names the subscription', () {
      expect(
        subscriptionAddedToast(servers: 12, name: 'Nebula Premium'),
        const ToastSpec(
          'Subscription added',
          subtitle: '12 SERVERS · NEBULA PREMIUM',
        ),
      );
    });

    test('says "server" for exactly one', () {
      expect(
        subscriptionAddedToast(servers: 1, name: 'Home').subtitle,
        '1 SERVER · HOME',
      );
    });
  });
}
