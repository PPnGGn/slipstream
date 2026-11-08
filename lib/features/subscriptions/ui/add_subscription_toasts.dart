import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:slipstream/core/service/toast/toast_message.dart';
import 'package:slipstream/features/subscriptions/data/subscription_parser/subscription_exceptions.dart';
import 'package:slipstream/features/subscriptions/data/subscription_parser/subscription_fetcher.dart';
import 'package:slipstream/l10n/l10n_context.dart';

// What the "Add subscription" sheet says, as toasts. The sheet only outlines
// the field in red; the words live here so they can be tested.

ToastSpec nothingToAddToast(AppLocalizations l10n) => ToastSpec(
  l10n.toastNothingToAddTitle,
  subtitle: l10n.toastNothingToAddHint,
  kind: ToastKind.error,
);

ToastSpec emptyClipboardToast(AppLocalizations l10n) => ToastSpec(
  l10n.toastClipboardEmptyTitle,
  subtitle: l10n.toastClipboardEmptyHint,
  kind: ToastKind.error,
);

ToastSpec noQrInImageToast(AppLocalizations l10n) => ToastSpec(
  l10n.toastNoQrTitle,
  subtitle: l10n.toastNoQrHint,
  kind: ToastKind.error,
);

/// Plain words for why an add failed. [cause] is the exception the parser
/// gave the cubit (`errorCause`); the technical text stays in the logs.
ToastSpec addFailedToast(AppLocalizations l10n, Object? cause) =>
    subscriptionFailedToast(l10n, cause, fallbackTitle: l10n.addFailedTitle);

/// The words for a failed fetch of a subscription, shared by adding and
/// refreshing: the cause decides them. [fallbackTitle] is the headline for a
/// cause nobody expected.
ToastSpec subscriptionFailedToast(
  AppLocalizations l10n,
  Object? cause, {
  required String fallbackTitle,
}) {
  final (title, hint) = switch (cause) {
    InvalidInputFormatException() => (
      l10n.failInvalidTitle,
      l10n.failInvalidHint,
    ),
    NoServersFoundException() => (
      l10n.failNoServersTitle,
      l10n.failNoServersHint,
    ),
    DuplicateSubscriptionException() => (
      l10n.failDuplicateTitle,
      l10n.failDuplicateHint,
    ),
    DeviceLimitReachedException() => (
      l10n.failDeviceLimitTitle,
      l10n.failDeviceLimitHint,
    ),
    HwidRequiredException() => (l10n.failHwidTitle, l10n.failHwidHint),
    HttpStatusException(statusCode: 401 || 403) => (
      l10n.failAccessDeniedTitle,
      l10n.failAccessDeniedHint,
    ),
    HttpStatusException(statusCode: 404) => (
      l10n.failNotFoundTitle,
      l10n.failNotFoundHint,
    ),
    HttpStatusException(statusCode: 429) => (
      l10n.failTooManyTitle,
      l10n.failTooManyHint,
    ),
    HttpStatusException(:final statusCode) when statusCode >= 500 => (
      l10n.failServerErrorTitle,
      l10n.failServerErrorHint(statusCode),
    ),
    HttpStatusException(:final statusCode) => (
      l10n.failRefusedTitle,
      l10n.failRefusedHint(statusCode),
    ),
    TimeoutException() => (l10n.failTimeoutTitle, l10n.failCheckConnectionHint),
    SocketException() || TlsException() || http.ClientException() => (
      l10n.failUnreachableTitle,
      l10n.failCheckConnectionHint,
    ),
    _ => (fallbackTitle, l10n.failSeeLogsHint),
  };
  return ToastSpec(title, subtitle: hint, kind: ToastKind.error);
}

ToastSpec subscriptionAddedToast(
  AppLocalizations l10n, {
  required int servers,
  required String name,
}) => ToastSpec(
  l10n.subAddedTitle,
  subtitle: '${l10n.serverCountUpper(servers)} · ${name.toUpperCase()}',
);
