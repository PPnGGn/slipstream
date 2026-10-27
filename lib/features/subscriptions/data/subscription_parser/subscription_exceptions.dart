// Why adding a subscription failed, as types. The `toString` of each one is
// the technical English line that goes to the logs; what the user reads is
// chosen from the type (see `addFailedToast`), never from this text.

/// The input is not a link, a JSON config or base64.
class InvalidInputFormatException implements Exception {
  const InvalidInputFormatException();

  @override
  String toString() =>
      'Unknown input format. Expected an http(s) link, vless://, vmess://, '
      'trojan://, hysteria2://, ss:// or a raw JSON config';
}

/// The input was read, but no server of a supported scheme came out of it.
class NoServersFoundException implements Exception {
  const NoServersFoundException();

  @override
  String toString() => 'No supported servers were found in the response';
}

/// The same subscription link is already in the list.
class DuplicateSubscriptionException implements Exception {
  const DuplicateSubscriptionException();

  @override
  String toString() => 'This subscription has already been added';
}

/// The panel answered, but with an error status.
class HttpStatusException implements Exception {
  const HttpStatusException(this.statusCode);

  final int statusCode;

  @override
  String toString() => 'HTTP error: $statusCode';
}
