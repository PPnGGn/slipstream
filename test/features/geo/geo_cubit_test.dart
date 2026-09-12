import 'package:flutter_test/flutter_test.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:slipstream/core/models/result.dart';
import 'package:slipstream/features/geo/cubit/geo_cubit.dart';
import 'package:slipstream/features/geo/data/geo_catalog.dart';
import 'package:slipstream/features/geo/data/geo_meta.dart';
import 'package:slipstream/features/geo/data/geo_release.dart';
import 'package:slipstream/features/geo/data/geo_repository.dart';

/// A repository whose `download()` stream is scripted per test.
class _FakeGeoRepository implements GeoRepository {
  _FakeGeoRepository({
    this.installedResult = const GeoNotInstalled(),
    this.latest,
    required this.downloadStream,
  });

  GeoInstalled installedResult;
  Result<GeoRelease>? latest;
  Stream<GeoDownloadProgress> Function() downloadStream;

  int latestReleaseCalls = 0;

  @override
  Future<GeoInstalled> installed() async => installedResult;

  @override
  Future<Result<GeoRelease>> latestRelease() async {
    latestReleaseCalls++;
    return latest ?? Failure('no release scripted');
  }

  @override
  Stream<GeoDownloadProgress> download(GeoRelease release) => downloadStream();

  @override
  void dispose() {}
}

GeoRelease _release(String tag) => GeoRelease(
  tag: tag,
  assets: {
    'geosite.dat': const GeoAsset(name: 'geosite.dat', url: 'x', size: 10),
    'geoip.dat': const GeoAsset(name: 'geoip.dat', url: 'y', size: 10),
  },
);

GeoMeta _meta(String tag) => GeoMeta(
  tag: tag,
  updatedAt: DateTime(2026),
  sha256: const {'geosite.dat': 'a', 'geoip.dat': 'b'},
  catalog: const GeoCatalog(site: {'geosite:category-ru'}, ip: {'geoip:ru'}),
);

void main() {
  late Talker talker;

  setUp(() => talker = Talker());

  test(
    'updateIfNewer reports failed when the download stream errors '
    '(not a premature success)',
    () async {
      final repo = _FakeGeoRepository(
        installedResult: GeoInstalledOk(_meta('OLD')),
        latest: Success(_release('NEW')),
        downloadStream: () async* {
          yield GeoDownloadProgress(5, 20);
          throw Exception('network dropped mid-download');
        },
      );
      final cubit = GeoCubit(repository: repo, talker: talker);
      await Future<void>.delayed(Duration.zero); // let _init settle

      final outcome = await cubit.updateIfNewer();

      expect(outcome, GeoUpdateOutcome.failed);
      expect(cubit.state, isA<GeoFailed>());
      await cubit.close();
    },
  );

  test('updateIfNewer installs and reports updated when the stream completes', () async {
    final repo = _FakeGeoRepository(
      installedResult: GeoInstalledOk(_meta('OLD')),
      latest: Success(_release('NEW')),
      downloadStream: () async* {
        yield GeoDownloadProgress(10, 20);
        yield GeoDownloadProgress(20, 20, meta: _meta('NEW'));
      },
    );
    final cubit = GeoCubit(repository: repo, talker: talker);
    await Future<void>.delayed(Duration.zero);

    final outcome = await cubit.updateIfNewer();

    expect(outcome, GeoUpdateOutcome.updated);
    expect(cubit.state, isA<GeoReady>());
    expect((cubit.state as GeoReady).tag, 'NEW');
    await cubit.close();
  });

  test('updateIfNewer is a single round-trip and is up-to-date on same tag', () async {
    final repo = _FakeGeoRepository(
      installedResult: GeoInstalledOk(_meta('SAME')),
      latest: Success(_release('SAME')),
      downloadStream: () async* {
        fail('download must not be called when the tag is unchanged');
      },
    );
    final cubit = GeoCubit(repository: repo, talker: talker);
    await Future<void>.delayed(Duration.zero);

    final outcome = await cubit.updateIfNewer();

    expect(outcome, GeoUpdateOutcome.upToDate);
    expect(cubit.state, isA<GeoReady>());
    expect(repo.latestReleaseCalls, 1); // not 2
    await cubit.close();
  });

  test('downloadLatest(known) skips the release lookup entirely', () async {
    final repo = _FakeGeoRepository(
      latest: Failure('should not be consulted'),
      downloadStream: () async* {
        yield GeoDownloadProgress(20, 20, meta: _meta('BOOT'));
      },
    );
    final cubit = GeoCubit(repository: repo, talker: talker);
    await Future<void>.delayed(Duration.zero);

    await cubit.downloadLatest(_release('BOOT'));

    expect(repo.latestReleaseCalls, 0);
    expect(cubit.state, isA<GeoReady>());
    await cubit.close();
  });
}
