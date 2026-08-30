import 'dart:convert';
import 'package:http/http.dart' as http;

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
  Future<String> fetchText(String url) async => (await fetch(url)).body;

  Future<SubscriptionResponse> fetch(String url) async {
    final response = await http
        .get(Uri.parse(url))
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
    final raw = header.startsWith('base64:')
        ? header.substring('base64:'.length)
        : header;
    try {
      final decoded = decodeBase64(raw).trim();
      return decoded.isNotEmpty ? decoded : null;
    } catch (_) {
      return header.trim().isNotEmpty ? header.trim() : null;
    }
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

  String decodeBase64(String str) {
    String normalized = str.replaceAll(RegExp(r'\s+'), '');
    final padding = normalized.length % 4;
    if (padding != 0) {
      normalized += '=' * (4 - padding);
    }
    try {
      return utf8.decode(base64Decode(normalized));
    } catch (_) {
      return utf8.decode(base64Url.decode(normalized));
    }
  }
}
