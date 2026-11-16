import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:slipstream/features/geo/data/geo_release_api.dart';
import 'package:slipstream/features/geo/data/geo_source.dart';

/// Where the geo files come from, and how a release is pinned.
///
/// `release.json` is read from `releases/latest/download/` (the one request that
/// has to find "the newest release"). Every file is then fetched from
/// `releases/download/<tag>/`, with the tag that `release.json` names: five
/// requests to `latest` could straddle a publish and mix two releases, and the
/// tag recorded in `geo.meta.json` would not match the files next to it.
void main() {
  const repo = 'https://github.com/PPnGGn/slipstream-georules';

  http.Response json(String body) =>
      http.Response(body, 200, headers: {'content-type': 'application/json'});

  group('GeoReleaseApi.fetchLatest', () {
    late List<Uri> asked;

    GeoReleaseApi apiAnswering(String releaseJson) {
      asked = [];
      return GeoReleaseApi(
        client: MockClient((request) async {
          asked.add(request.url);
          return json(releaseJson);
        }),
      );
    }

    test(
      'reads release.json from the latest release, in the renamed repo',
      () async {
        final api = apiAnswering('{"tag":"20261113-1755","sizes":{}}');

        await api.fetchLatest();

        expect(asked.map((u) => u.toString()), [
          '$repo/releases/latest/download/release.json',
        ]);
      },
    );

    test('points every asset at the tag release.json names', () async {
      final api = apiAnswering(
        '{"tag":"20261113-1755","sizes":'
        '{"geosite.dat":4865788,"geoip.dat":17919523,"categories.json":4617}}',
      );

      final release = await api.fetchLatest();

      expect(release.tag, '20261113-1755');
      for (final name in [
        'geosite.dat',
        'geoip.dat',
        'categories.json',
        'sha256sums.txt',
      ]) {
        expect(
          release.assetOrThrow(name).url,
          '$repo/releases/download/20261113-1755/$name',
        );
      }
      expect(release.assetOrThrow('geosite.dat').size, 4865788);
      expect(release.assetOrThrow('geoip.dat').size, 17919523);
      expect(release.assetOrThrow('categories.json').size, 4617);
    });

    test('no URL still names the old repository', () async {
      final api = apiAnswering('{"tag":"20261113-1755","sizes":{}}');

      final release = await api.fetchLatest();

      for (final asset in release.assets.values) {
        expect(asset.url, isNot(contains('slipstream-rules')));
        expect(asset.url, isNot(contains('/latest/')));
      }
      expect(asked.single.toString(), isNot(contains('slipstream-rules')));
    });

    test('a tag that could redirect the URL is refused', () async {
      for (final tag in [
        '../x',
        'a/b',
        '',
        'a b',
        '20261113-1755/..',
        '?x=1',
      ]) {
        final api = apiAnswering('{"tag":"$tag","sizes":{}}');

        await expectLater(
          api.fetchLatest(),
          throwsA(isA<ArgumentError>()),
          reason: 'tag "$tag" must not reach a URL',
        );
      }
    });
  });

  group('GeoSource', () {
    const source = GeoSource();

    test('the latest-release URL is only for release.json', () {
      expect(
        source.releaseInfoUrl,
        '$repo/releases/latest/download/release.json',
      );
    });

    test('assetUrl pins a file to a tag', () {
      expect(
        source.assetUrl('20261113-1755', 'geoip.dat'),
        '$repo/releases/download/20261113-1755/geoip.dat',
      );
    });

    test('assetUrl accepts the tags the build workflow produces', () {
      for (final tag in ['20261113-1755', '20260909-0911', 'v1.2.3', '1']) {
        expect(() => source.assetUrl(tag, 'geosite.dat'), returnsNormally);
      }
    });

    test('assetUrl refuses a tag with path or query characters', () {
      for (final tag in ['../x', 'a/b', '', 'a?b', 'a#b', 'a%2Fb', ' x']) {
        expect(
          () => source.assetUrl(tag, 'geosite.dat'),
          throwsArgumentError,
          reason: 'tag "$tag"',
        );
      }
    });
  });
}
