import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:slipstream/features/routing/data/local_proxy_client.dart';
import 'geo_release.dart';
import 'geo_source.dart';

/// Reads the latest `slipstream-rules` release straight from
/// `releases/latest/download/…` — no GitHub API call.
///
/// `api.github.com` is rate-limited to 60 requests/hour **per IP**
/// unauthenticated. The app fetches geo *through the active tunnel* (GitHub is
/// often unreachable from Russia without a VPN), so every user behind one exit
/// node shares that node's IP and quota — the API is unusable here.
/// `releases/latest/download/<name>` 302-redirects to the asset with no API
/// budget; `release.json` (written by the build workflow) carries the tag and
/// asset sizes the API used to provide.
class GeoReleaseApi {
  GeoReleaseApi({
    http.Client? client,
    LocalProxyProvider? proxy,
    GeoSource source = const GeoSource(),
  }) : _overrideClient = client,
       _proxy = proxy,
       _source = source;

  /// A caller-supplied client (tests). When set it's used as-is and never
  /// closed here; otherwise a fresh client is built per call, routed through
  /// the active connection's local proxy if there is one.
  final http.Client? _overrideClient;
  final LocalProxyProvider? _proxy;
  final GeoSource _source;

  Future<GeoRelease> fetchLatest() async {
    // With a refresh: the core can restart while the request is on its way (the
    // user picks another server while connected), and the request is then sent
    // again once with the password of the new session.
    final client =
        _overrideClient ??
        buildProxiedClient(await _proxy?.current(), refresh: _proxy?.current);
    try {
      final info =
          jsonDecode(await _get(client, _source.releaseInfoUrl))
              as Map<String, dynamic>;
      final tag = info['tag'] as String;
      final sizes =
          (info['sizes'] as Map?)?.cast<String, dynamic>() ?? const {};

      final assets = <String, GeoAsset>{
        for (final name in const [
          GeoSource.geositeFile,
          GeoSource.geoipFile,
          GeoSource.catalogFile,
        ])
          name: GeoAsset(
            name: name,
            url: _source.downloadUrl(name),
            size: (sizes[name] as num?)?.toInt() ?? 0,
          ),
        // sha256sums.txt: fetched as text by the repository, tiny, no size
        // in release.json and not part of download progress.
        GeoSource.checksumsFile: GeoAsset(
          name: GeoSource.checksumsFile,
          url: _source.downloadUrl(GeoSource.checksumsFile),
          size: 0,
        ),
      };
      return GeoRelease(tag: tag, assets: assets);
    } finally {
      if (_overrideClient == null) client.close();
    }
  }

  Future<String> _get(http.Client client, String url) async {
    final r = await client
        .get(Uri.parse(url))
        .timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw Exception('Timeout fetching $url'),
        );
    if (r.statusCode != 200) {
      throw Exception('HTTP ${r.statusCode} for $url');
    }
    return r.body;
  }

  void dispose() => _overrideClient?.close();
}
