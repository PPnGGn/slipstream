import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:injectable/injectable.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:slipstream/core/models/result.dart';
import 'package:slipstream/features/routing/data/local_proxy_client.dart';
import 'package:slipstream/features/routing/data/local_proxy_gate.dart';
import 'geo_catalog.dart';
import 'geo_meta.dart';
import 'geo_paths.dart';
import 'geo_release.dart';
import 'geo_release_api.dart';
import 'geo_source.dart';

/// What's on disk right now.
sealed class GeoInstalled {
  const GeoInstalled();
}

class GeoNotInstalled extends GeoInstalled {
  const GeoNotInstalled();
}

class GeoInstalledOk extends GeoInstalled {
  const GeoInstalledOk(this.meta);
  final GeoMeta meta;
}

/// Fetches, verifies and swaps in the trimmed geo databases. Download flow
/// mirrors `features/update/data/update_repository.dart` (streamed progress,
/// atomic `.tmp` -> rename); adds sha256 verification against the release's
/// `sha256sums.txt`.
@lazySingleton
class GeoRepository {
  GeoRepository(
    this._paths,
    this._talker,
    LocalProxyPort proxyPort, {
    @ignoreParam GeoReleaseApi? releaseApi,
    @ignoreParam http.Client Function(int?)? clientFactory,
  }) : _proxyPort = proxyPort,
       _clientFactory = clientFactory ?? buildProxiedClient,
       _releaseApi = releaseApi ?? GeoReleaseApi(proxyPort: proxyPort);

  final GeoPaths _paths;
  final Talker _talker;
  final LocalProxyPort _proxyPort;
  final GeoReleaseApi _releaseApi;
  final http.Client Function(int?) _clientFactory;

  Future<String> get _dir => _paths.dir();

  /// Reads `geo.meta.json` and confirms the .dat files exist and still match
  /// the recorded checksums. Any mismatch -> not installed.
  Future<GeoInstalled> installed() async {
    final dir = await _dir;
    final meta = await GeoMeta.read(dir);
    if (meta == null) return const GeoNotInstalled();

    for (final name in const [GeoSource.geositeFile, GeoSource.geoipFile]) {
      final f = File('$dir${Platform.pathSeparator}$name');
      final want = meta.sha256[name];
      if (!f.existsSync() || want == null) return const GeoNotInstalled();
      final got = await _sha256OfFile(f);
      if (got != want) {
        _talker.warning('Geo: $name checksum drift, treating as not installed');
        return const GeoNotInstalled();
      }
    }
    return GeoInstalledOk(meta);
  }

  Future<Result<GeoRelease>> latestRelease() async {
    try {
      return Success(await _releaseApi.fetchLatest());
    } catch (e, st) {
      _talker.handle(e, st, 'Geo: failed to fetch latest release');
      return Failure('Failed to check geo updates: $e');
    }
  }

  /// Downloads every asset of [release], verifies checksums, atomically swaps
  /// the .dat files in and writes `geo.meta.json`. Emits bytes-received across
  /// all files; completes with the new [GeoMeta] or errors.
  ///
  /// All requests go through one client built for the *current* connection —
  /// routed via the core's local proxy when a tunnel is up (the app is
  /// excluded from its own tunnel, so this is how the download rides an
  /// active connection). Any `.tmp` file is cleaned up on failure.
  Stream<GeoDownloadProgress> download(GeoRelease release) async* {
    final dir = await _dir;
    final total = release.totalBytes;
    var received = 0;

    final client = _clientFactory(_proxyPort.value);
    final tmpPaths = [
      for (final name in const [GeoSource.geositeFile, GeoSource.geoipFile])
        '$dir${Platform.pathSeparator}$name.tmp',
    ];
    try {
      // 1. checksums first — tiny, and we need it to verify the rest.
      final sums = _parseSums(
        await _fetchText(
          client,
          release.assetOrThrow(GeoSource.checksumsFile).url,
        ),
      );

      // 2. the big files -> .tmp.
      final tmp = <String, String>{}; // name -> tmp path
      for (final name in const [GeoSource.geositeFile, GeoSource.geoipFile]) {
        final asset = release.assetOrThrow(name);
        final tmpPath = '$dir${Platform.pathSeparator}$name.tmp';
        await for (final n in _downloadTo(client, asset, tmpPath)) {
          received += n;
          yield GeoDownloadProgress(received, total);
        }
        await _verifyFile(tmpPath, sums[name], name);
        tmp[name] = tmpPath;
      }

      // 3. categories.json — fetch, verify, parse, keep only in meta.
      final catalogAsset = release.assetOrThrow(GeoSource.catalogFile);
      final catalogText = await _fetchText(client, catalogAsset.url);
      _verifyBytes(
        utf8.encode(catalogText),
        sums[GeoSource.catalogFile],
        GeoSource.catalogFile,
      );
      final catalog = GeoCatalog.fromJson(
        jsonDecode(catalogText) as Map<String, dynamic>,
      );

      // 4. commit: rename .tmp over the live files, then write meta.
      for (final entry in tmp.entries) {
        await File(
          entry.value,
        ).rename('$dir${Platform.pathSeparator}${entry.key}');
      }
      final meta = GeoMeta(
        tag: release.tag,
        updatedAt: DateTime.now(),
        sha256: {
          GeoSource.geositeFile: sums[GeoSource.geositeFile]!,
          GeoSource.geoipFile: sums[GeoSource.geoipFile]!,
        },
        catalog: catalog,
      );
      await meta.write(dir);
      _talker.info(
        'Geo: installed ${release.tag} '
        '(${catalog.site.length} site / ${catalog.ip.length} ip categories)',
      );
      yield GeoDownloadProgress(total, total, meta: meta);
    } finally {
      client.close();
      for (final p in tmpPaths) {
        final f = File(p);
        if (f.existsSync()) {
          try {
            await f.delete();
          } catch (_) {/* best effort */}
        }
      }
    }
  }

  Stream<int> _downloadTo(http.Client client, GeoAsset asset, String toPath) {
    final controller = StreamController<int>();
    controller.onListen = () async {
      IOSink? sink;
      try {
        final response = await client.send(
          http.Request('GET', Uri.parse(asset.url)),
        );
        if (response.statusCode != 200) {
          throw Exception('HTTP ${response.statusCode} for ${asset.name}');
        }
        sink = File(toPath).openWrite();
        await response.stream.forEach((chunk) {
          sink!.add(chunk);
          controller.add(chunk.length);
        });
        await sink.close();
        final len = await File(toPath).length();
        if (asset.size > 0 && len != asset.size) {
          throw Exception(
            '${asset.name}: got $len bytes, expected ${asset.size}',
          );
        }
        await controller.close();
      } catch (e, st) {
        await sink?.close();
        controller.addError(e, st);
        await controller.close();
      }
    };
    return controller.stream;
  }

  Future<String> _fetchText(http.Client client, String url) async {
    final r = await client
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 15));
    if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode} for $url');
    return r.body;
  }

  /// sha256 of a file, hashed in chunks so a 20 MB read never lands on the
  /// heap (or the UI isolate) all at once.
  Future<String> _sha256OfFile(File f) async {
    late Digest digest;
    final input = sha256.startChunkedConversion(
      ChunkedConversionSink<Digest>.withCallback((digests) {
        digest = digests.single;
      }),
    );
    await for (final chunk in f.openRead()) {
      input.add(chunk);
    }
    input.close();
    return digest.toString();
  }

  Future<void> _verifyFile(String path, String? want, String name) async {
    if (want == null) throw Exception('sha256sums.txt has no entry for $name');
    final got = await _sha256OfFile(File(path));
    if (got != want) {
      throw Exception('$name checksum mismatch: got $got, want $want');
    }
  }

  void _verifyBytes(List<int> bytes, String? want, String name) {
    if (want == null) throw Exception('sha256sums.txt has no entry for $name');
    final got = sha256.convert(bytes).toString();
    if (got != want) {
      throw Exception('$name checksum mismatch: got $got, want $want');
    }
  }

  /// coreutils `sha256sum` output: `<hex>  <name>` per line.
  Map<String, String> _parseSums(String text) {
    final out = <String, String>{};
    for (final line in const LineSplitter().convert(text)) {
      final m = RegExp(r'^([0-9a-fA-F]{64})\s+\*?(.+)$').firstMatch(line.trim());
      if (m != null) out[m.group(2)!.trim()] = m.group(1)!.toLowerCase();
    }
    return out;
  }

  @disposeMethod
  void dispose() {
    _releaseApi.dispose();
  }
}

class GeoDownloadProgress {
  const GeoDownloadProgress(this.received, this.total, {this.meta});

  final int received;
  final int total;

  /// Non-null only on the final event — the install is done.
  final GeoMeta? meta;

  double get fraction => total == 0 ? 0 : (received / total).clamp(0.0, 1.0);
  bool get done => meta != null;
}
