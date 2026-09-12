import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:slipstream/features/geo/data/geo_paths.dart';
import 'package:slipstream/features/geo/data/geo_release.dart';
import 'package:slipstream/features/geo/data/geo_repository.dart';
import 'package:slipstream/features/geo/data/geo_source.dart';
import 'package:slipstream/features/routing/data/local_proxy_gate.dart';

class _FixedPaths implements GeoPaths {
  _FixedPaths(this._dir);
  final String _dir;
  @override
  Future<String> dir() async => _dir;
}

void main() {
  late Directory tmp;
  late String geoDir;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('geo_repo_test');
    geoDir = tmp.path;
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  final geositeBytes = utf8.encode('geosite-payload');
  final geoipBytes = utf8.encode('geoip-payload');
  final catalog = jsonEncode({
    'site': ['geosite:category-ru'],
    'ip': ['geoip:ru'],
  });
  String sums() {
    String h(List<int> b) => sha256.convert(b).toString();
    return '${h(geositeBytes)}  geosite.dat\n'
        '${h(geoipBytes)}  geoip.dat\n'
        '${h(utf8.encode(catalog))}  categories.json\n';
  }

  GeoRelease release() => GeoRelease(
    tag: '20260101-0000',
    assets: {
      GeoSource.geositeFile: GeoAsset(
        name: GeoSource.geositeFile,
        url: 'https://x/geosite.dat',
        size: geositeBytes.length,
      ),
      GeoSource.geoipFile: GeoAsset(
        name: GeoSource.geoipFile,
        url: 'https://x/geoip.dat',
        size: geoipBytes.length,
      ),
      GeoSource.catalogFile: GeoAsset(
        name: GeoSource.catalogFile,
        url: 'https://x/categories.json',
        size: 0,
      ),
      GeoSource.checksumsFile: GeoAsset(
        name: GeoSource.checksumsFile,
        url: 'https://x/sha256sums.txt',
        size: 0,
      ),
    },
  );

  GeoRepository repoWith(http.Client client) => GeoRepository(
    _FixedPaths(geoDir),
    Talker(),
    LocalProxyPort(),
    clientFactory: (_) => client,
  );

  test('happy path installs both .dat files and writes meta', () async {
    final client = MockClient((req) async {
      final url = req.url.toString();
      if (url.endsWith('sha256sums.txt')) return http.Response(sums(), 200);
      if (url.endsWith('categories.json')) return http.Response(catalog, 200);
      if (url.endsWith('geosite.dat')) {
        return http.Response.bytes(geositeBytes, 200);
      }
      if (url.endsWith('geoip.dat')) return http.Response.bytes(geoipBytes, 200);
      return http.Response('not found', 404);
    });

    final events = await repoWith(client).download(release()).toList();

    expect(events.last.done, isTrue);
    expect(File('$geoDir/geosite.dat').readAsBytesSync(), geositeBytes);
    expect(File('$geoDir/geoip.dat').readAsBytesSync(), geoipBytes);
    expect(File('$geoDir/${GeoSource.metaFile}').existsSync(), isTrue);
    // no .tmp left behind
    expect(File('$geoDir/geosite.dat.tmp').existsSync(), isFalse);
    expect(File('$geoDir/geoip.dat.tmp').existsSync(), isFalse);
  });

  test('a checksum mismatch fails the stream and cleans up .tmp files', () async {
    final client = MockClient((req) async {
      final url = req.url.toString();
      if (url.endsWith('sha256sums.txt')) return http.Response(sums(), 200);
      if (url.endsWith('categories.json')) return http.Response(catalog, 200);
      if (url.endsWith('geosite.dat')) {
        return http.Response.bytes(utf8.encode('CORRUPTED'), 200);
      }
      if (url.endsWith('geoip.dat')) return http.Response.bytes(geoipBytes, 200);
      return http.Response('not found', 404);
    });

    await expectLater(
      repoWith(client).download(release()).toList(),
      throwsA(isA<Exception>()),
    );

    expect(File('$geoDir/geosite.dat').existsSync(), isFalse);
    expect(File('$geoDir/geosite.dat.tmp').existsSync(), isFalse);
    expect(File('$geoDir/geoip.dat.tmp').existsSync(), isFalse);
    expect(File('$geoDir/${GeoSource.metaFile}').existsSync(), isFalse);
  });

  test('installed() confirms a good install and rejects checksum drift', () async {
    final client = MockClient((req) async {
      final url = req.url.toString();
      if (url.endsWith('sha256sums.txt')) return http.Response(sums(), 200);
      if (url.endsWith('categories.json')) return http.Response(catalog, 200);
      if (url.endsWith('geosite.dat')) {
        return http.Response.bytes(geositeBytes, 200);
      }
      return http.Response.bytes(geoipBytes, 200);
    });
    final repo = repoWith(client);
    await repo.download(release()).toList();

    expect(await repo.installed(), isA<GeoInstalledOk>());

    // tamper with a file on disk
    File('$geoDir/geoip.dat').writeAsBytesSync(utf8.encode('tampered'));
    expect(await repo.installed(), isA<GeoNotInstalled>());
  });
}
