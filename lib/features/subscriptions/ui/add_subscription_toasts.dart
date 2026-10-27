import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:slipstream/core/service/toast/toast_message.dart';
import 'package:slipstream/features/subscriptions/data/subscription_parser/subscription_exceptions.dart';
import 'package:slipstream/features/subscriptions/data/subscription_parser/subscription_fetcher.dart';

// What the "Add subscription" sheet says, as toasts. The sheet only outlines
// the field in red; the words live here so they can be tested.

const nothingToAddToast = ToastSpec(
  'Nothing to add',
  subtitle: 'PASTE A LINK OR KEY FIRST',
  kind: ToastKind.error,
);

const emptyClipboardToast = ToastSpec(
  'Clipboard is empty',
  subtitle: 'COPY A LINK OR KEY FIRST',
  kind: ToastKind.error,
);

const noQrInImageToast = ToastSpec(
  'No QR code found',
  subtitle: 'TRY ANOTHER IMAGE',
  kind: ToastKind.error,
);

/// Plain words for why an add failed. [cause] is the exception the parser
/// gave the cubit (`errorCause`); the technical text stays in the logs.
ToastSpec addFailedToast(Object? cause) =>
    subscriptionFailedToast(cause, fallbackTitle: "Couldn't add subscription");

/// The words for a failed fetch of a subscription, shared by adding and
/// refreshing: the cause decides them. [fallbackTitle] is the headline for a
/// cause nobody expected.
ToastSpec subscriptionFailedToast(
  Object? cause, {
  required String fallbackTitle,
}) {
  final (title, hint) = switch (cause) {
    InvalidInputFormatException() => (
      'Invalid key or link',
      'CHECK THAT IT IS COPIED IN FULL',
    ),
    NoServersFoundException() => (
      'No servers found',
      'NOTHING IN IT THE APP SUPPORTS',
    ),
    DuplicateSubscriptionException() => (
      'Already added',
      'THIS SUBSCRIPTION IS IN YOUR LIST',
    ),
    DeviceLimitReachedException() => (
      'Device limit reached',
      'ASK THE PROVIDER TO REMOVE AN OLD DEVICE',
    ),
    HwidRequiredException() => (
      'Provider rejected this device',
      'TRY LATER OR CONTACT THE PROVIDER',
    ),
    HttpStatusException(statusCode: 401 || 403) => (
      'Access denied',
      'THE LINK MAY BE EXPIRED OR REVOKED',
    ),
    HttpStatusException(statusCode: 404) => (
      'Link not found',
      'CHECK THE LINK',
    ),
    HttpStatusException(statusCode: 429) => (
      'Too many requests',
      'WAIT A MINUTE AND TRY AGAIN',
    ),
    HttpStatusException(:final statusCode) when statusCode >= 500 => (
      'Provider server error',
      'TRY AGAIN LATER · HTTP $statusCode',
    ),
    HttpStatusException(:final statusCode) => (
      'Provider refused the link',
      'HTTP $statusCode',
    ),
    TimeoutException() => (
      "Server didn't respond",
      'CHECK CONNECTION · TRY AGAIN',
    ),
    SocketException() ||
    TlsException() ||
    http.ClientException() => (
      "Can't reach the server",
      'CHECK CONNECTION · TRY AGAIN',
    ),
    _ => (fallbackTitle, 'SEE APP LOGS FOR DETAILS'),
  };
  return ToastSpec(title, subtitle: hint, kind: ToastKind.error);
}

ToastSpec subscriptionAddedToast({required int servers, required String name}) {
  final noun = servers == 1 ? 'SERVER' : 'SERVERS';
  return ToastSpec(
    'Subscription added',
    subtitle: '$servers $noun · ${name.toUpperCase()}',
  );
}
