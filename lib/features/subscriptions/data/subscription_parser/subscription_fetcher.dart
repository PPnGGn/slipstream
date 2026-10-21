import 'package:http/http.dart' as http;
import 'package:injectable/injectable.dart';
import 'package:slipstream/features/client_identity/data/client_identity_repository.dart';
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

@lazySingleton
class SubscriptionFetcher {
  final ClientIdentityRepository _identity;
  final http.Client _client;

  SubscriptionFetcher(this._identity, {@ignoreParam http.Client? client})
    : _client = client ?? http.Client();

  Future<SubscriptionResponse> fetch(String url) async {
    final identity = await _identity.current();
    final response = await _client
        .get(Uri.parse(url), headers: identity.toHeaders())
        .timeout(
          const Duration(seconds: 10),
          onTimeout: () =>
              throw Exception('Timeout: server did not respond in 10 seconds'),
        );
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
