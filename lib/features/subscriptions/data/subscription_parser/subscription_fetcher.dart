import 'package:http/http.dart' as http;
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

class SubscriptionFetcher {
  final http.Client _client;

  SubscriptionFetcher({http.Client? client})
    : _client = client ?? http.Client();

  static const _userAgent = 'slipstream';

  Future<SubscriptionResponse> fetch(String url) async {
    final response = await _client
        .get(Uri.parse(url), headers: const {'User-Agent': _userAgent})
        .timeout(
          const Duration(seconds: 10),
          onTimeout: () =>
              throw Exception('Timeout: server did not respond in 10 seconds'),
        );
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
