/// Where the trimmed geo databases come from.
///
/// The `slipstream-rules` repo runs a weekly job that trims RunetFreedom's
/// geosite.dat / geoip.dat down to an allowlist and publishes a Release with:
///   - geosite.dat, geoip.dat          (xray format, trimmed)
///   - categories.json                 ({"site": [...], "ip": [...]})
///   - sha256sums.txt                  (coreutils format)
///   - release.json                    ({"tag": "...", "sizes": {...}})
class GeoSource {
  const GeoSource();

  /// `releases/latest/download/<name>` 302-redirects to the current release's
  /// asset — no GitHub API call, so no unauthenticated 60-req/hour-per-IP
  /// limit (which the app can't live with once every user downloads through
  /// the same exit node's shared IP).
  String downloadUrl(String assetName) =>
      'https://github.com/PPnGGn/slipstream-rules/releases/latest/download/$assetName';

  /// Tag + asset sizes, published by the build workflow so the app learns
  /// them without the GitHub API.
  String get releaseInfoUrl => downloadUrl(releaseInfoFile);

  /// Asset filenames inside a release. `geositeFile` / `geoipFile` are also the
  /// on-disk names xray expects in the asset dir — keep them identical.
  static const geositeFile = 'geosite.dat';
  static const geoipFile = 'geoip.dat';
  static const catalogFile = 'categories.json';
  static const checksumsFile = 'sha256sums.txt';
  static const releaseInfoFile = 'release.json';

  /// Local sidecar (not from the release) recording what's installed.
  static const metaFile = 'geo.meta.json';
}
