/// Where the trimmed geo databases come from.
///
/// The `slipstream-georules` repo runs a weekly job that trims RunetFreedom's
/// geosite.dat / geoip.dat down to an allowlist and publishes a Release with:
///   - geosite.dat, geoip.dat          (xray format, trimmed)
///   - categories.json                 ({"site": [...], "ip": [...]})
///   - sha256sums.txt                  (coreutils format)
///   - release.json                    ({"tag": "...", "sizes": {...}})
///
/// The repository used to be called `slipstream-rules`. GitHub redirects the old
/// name, so older app versions keep working, but only for as long as nobody
/// creates a repository of that name again: this app names the new one.
class GeoSource {
  const GeoSource();

  static const _repo = 'https://github.com/PPnGGn/slipstream-georules';

  /// Tag + asset sizes, published by the build workflow so the app learns
  /// them without the GitHub API. This is the one request that goes to
  /// `releases/latest/download/` (it 302-redirects to the newest release, with
  /// no unauthenticated 60-req/hour-per-IP API limit, which the app can't live
  /// with once every user downloads through the same exit node's shared IP).
  String get releaseInfoUrl =>
      '$_repo/releases/latest/download/$releaseInfoFile';

  /// A file of the release [tag], from `releases/download/<tag>/`.
  ///
  /// Everything but `release.json` is fetched by tag, not from `latest`: the
  /// download is several requests, and a release published in between would
  /// otherwise hand the app a geosite.dat of one release and a geoip.dat (and
  /// checksums) of the next. The tag comes from a file on the network, so it is
  /// held to what the build workflow produces (`20261113-1755`) before it is put
  /// in a URL.
  String assetUrl(String tag, String assetName) {
    if (!_safeTag.hasMatch(tag)) {
      throw ArgumentError.value(tag, 'tag', 'not a release tag of this repo');
    }
    return '$_repo/releases/download/$tag/$assetName';
  }

  static final _safeTag = RegExp(r'^[0-9A-Za-z][0-9A-Za-z._-]{0,63}$');

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
