import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:injectable/injectable.dart';
import 'package:slipstream/features/client_identity/data/client_identity_repository.dart';
import 'package:slipstream/features/routing/data/local_proxy_client.dart';
import 'package:slipstream/features/vpn/data/vpn_api.g.dart';
import 'base64_codec.dart';

class SubscriptionResponse {
  final String body;
  final String? profileTitle;
  final String? announce;
  final DateTime? expiresAt;
  final int? updateIntervalHours;
  final int? usedBytes;
  final int? dataLimitBytes;

  SubscriptionResponse({
    required this.body,
    this.profileTitle,
    this.announce,
    this.expiresAt,
    this.updateIntervalHours,
    this.usedBytes,
    this.dataLimitBytes,
  });
}

/// The panel refused the request because the subscription has no free
/// device slot left (`x-hwid-max-devices-reached`).
class DeviceLimitReachedException implements Exception {
  const DeviceLimitReachedException();

  @override
  String toString() =>
      'This subscription has reached its device limit. Ask the provider to '
      'remove an old device, then try again.';
}

/// The panel answered 404 with `x-hwid-not-supported`: it enforces a device
/// limit but did not accept the HWID we sent.
class HwidRequiredException implements Exception {
  const HwidRequiredException();

  @override
  String toString() =>
      'The panel requires a device ID (HWID) and did not accept ours. Try '
      'again later or contact the provider.';
}

/// Fetches a subscription URL: direct first, then through the tunnel.
///
/// The app is excluded from its own tunnel, so a plain request goes direct
/// even while the VPN is on. When the provider's domain is blocked, that
/// request dies at the network level; if a tunnel is up, it is retried once
/// through the core's local proxy (the same route [GeoRepository] uses).
/// Anything the panel itself answered — an error status, a device limit — is
/// final and never retried.
@lazySingleton
class SubscriptionFetcher {
  final ClientIdentityRepository _identity;
  final LocalProxyProvider _proxy;
  final http.Client Function(LocalProxyMessage?) _clientFactory;

  SubscriptionFetcher(
    this._identity,
    this._proxy, {
    @ignoreParam http.Client Function(LocalProxyMessage?)? clientFactory,
  }) : _clientFactory = clientFactory ?? refreshingProxyClientFactory(_proxy);

  Future<SubscriptionResponse> fetch(String url) async {
    final identity = await _identity.current();
    final requestHeaders = identity.toHeaders();

    http.Response response;
    try {
      response = await _get(url, requestHeaders, null);
    } catch (e) {
      if (!_isNetworkError(e)) rethrow;
      final proxy = await _proxy.current();
      if (proxy == null) rethrow;
      response = await _get(url, requestHeaders, proxy);
    }

    // Before the status check: these replies come with an error status, and
    // a bare "HTTP error: 404" would hide the real reason from the user.
    _throwIfHwidRefused(response);
    if (response.statusCode != 200) {
      throw Exception('HTTP error: ${response.statusCode}');
    }
    final headers = response.headers;
    final userInfo = _parseUserInfo(headers['subscription-userinfo']);
    return SubscriptionResponse(
      body: response.body,
      profileTitle: _decodeTextHeader(headers['profile-title']),
      announce: _decodeTextHeader(headers['announce']),
      expiresAt: userInfo.expiresAt,
      usedBytes: userInfo.usedBytes,
      dataLimitBytes: userInfo.dataLimitBytes,
      updateIntervalHours: int.tryParse(
        headers['profile-update-interval']?.trim() ?? '',
      ),
    );
  }

  /// One request on a fresh client: the proxy's port and password change
  /// every session, so a client is never reused across attempts.
  Future<http.Response> _get(
    String url,
    Map<String, String> headers,
    LocalProxyMessage? proxy,
  ) async {
    final client = _clientFactory(proxy);
    try {
      return await client
          .get(Uri.parse(url), headers: headers)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw TimeoutException(
              'Timeout: server did not respond in 10 seconds',
            ),
          );
    } finally {
      client.close();
    }
  }

  /// The request never reached the panel: refused, reset (DPI), TLS cut off
  /// mid-handshake, or no answer in time.
  static bool _isNetworkError(Object e) =>
      e is SocketException ||
      e is TlsException ||
      e is http.ClientException ||
      e is TimeoutException;

  // The exact reply of a full panel is not documented, so the limit header is
  // honored on any status.
  void _throwIfHwidRefused(http.Response response) {
    bool isTrue(String name) =>
        response.headers[name]?.trim().toLowerCase() == 'true';

    if (isTrue('x-hwid-max-devices-reached')) {
      throw const DeviceLimitReachedException();
    }
    if (response.statusCode == 404 && isTrue('x-hwid-not-supported')) {
      throw const HwidRequiredException();
    }
  }

  /// Decodes a header that may be plain text or `base64:<payload>`.
  String? _decodeTextHeader(String? header) {
    if (header == null || header.isEmpty) return null;
    final plain = header.trim();
    if (!header.startsWith('base64:')) {
      return plain.isNotEmpty ? plain : null;
    }
    final decoded = tryDecodeBase64(header.substring('base64:'.length))?.trim();
    if (decoded != null && decoded.isNotEmpty) return decoded;
    return plain.isNotEmpty ? plain : null;
  }

  ({DateTime? expiresAt, int? usedBytes, int? dataLimitBytes}) _parseUserInfo(
    String? header,
  ) {
    if (header == null || header.isEmpty) {
      return (expiresAt: null, usedBytes: null, dataLimitBytes: null);
    }

    final values = <String, int>{};
    for (final part in header.split(';')) {
      final pair = part.split('=');
      if (pair.length != 2) continue;
      final value = int.tryParse(pair[1].trim());
      if (value != null) values[pair[0].trim()] = value;
    }

    final expire = values['expire'];
    final total = values['total'];
    final used = (values['upload'] ?? 0) + (values['download'] ?? 0);

    return (
      expiresAt: (expire != null && expire > 0)
          ? DateTime.fromMillisecondsSinceEpoch(expire * 1000)
          : null,
      usedBytes: values.containsKey('upload') || values.containsKey('download')
          ? used
          : null,
      dataLimitBytes: (total != null && total > 0) ? total : null,
    );
  }
}
