import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:slipstream/core/models/app_release/app_release.dart';

class GithubReleaseApi {
  static const _latestReleaseUrl =
      'https://api.github.com/repos/PPnGGn/slipstream/releases/latest';
  static const _apkAssetName = 'slipstream-android.apk';

  Future<AppRelease> fetchLatest() async {
    final response = await http
        .get(Uri.parse(_latestReleaseUrl))
        .timeout(
          const Duration(seconds: 10),
          onTimeout: () =>
              throw Exception('Timeout: GitHub did not respond in 10 seconds'),
        );
    if (response.statusCode != 200) {
      throw Exception('HTTP error: ${response.statusCode}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final tagName = json['tag_name'] as String;
    final assets = json['assets'] as List<dynamic>;
    final apk = assets
        .cast<Map<String, dynamic>>()
        .where((asset) => asset['name'] == _apkAssetName)
        .firstOrNull;
    if (apk == null) {
      throw Exception('Release $tagName has no $_apkAssetName asset');
    }

    final (version, buildNumber) = _parseTag(tagName);
    return AppRelease(
      version: version,
      buildNumber: buildNumber,
      tagName: tagName,
      downloadUrl: apk['browser_download_url'] as String,
      sizeBytes: apk['size'] as int,
      notes: (json['body'] as String?)?.trim(),
    );
  }

  /// "v1.2.0+3" -> ("1.2.0", 3).
  (String, int) _parseTag(String tagName) {
    final raw = tagName.startsWith('v') ? tagName.substring(1) : tagName;
    final parts = raw.split('+');
    final build = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return (parts.first, build);
  }
}
