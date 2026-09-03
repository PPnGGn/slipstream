import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:injectable/injectable.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:slipstream/core/models/app_release/app_release.dart';
import 'package:slipstream/core/models/result.dart';
import 'package:slipstream/features/update/data/app_version.dart';
import 'package:slipstream/features/update/data/github_release_api.dart';
import 'package:slipstream/features/update/data/update_cache.dart';
import 'package:slipstream/features/update/data/update_check.dart';
import 'package:slipstream/features/update/data/updater_api.g.dart';

@lazySingleton
class UpdateRepository {
  final Talker _talker;
  final GithubReleaseApi _releaseApi;
  final UpdateInstaller _installer;
  final Directory _updatesDir;
  final http.Client _client = http.Client();

  UpdateRepository(
    Talker talker,
    this._installer,
    @Named('updatesDir') this._updatesDir,
  ) : _talker = talker,
      _releaseApi = GithubReleaseApi();

  Future<Result<UpdateCheck>> checkAndResolveCache() async {
    try {
      final current = await _installer.getAppVersion();
      final release = await _releaseApi.fetchLatest();
      final newer = isNewerVersion(
        current: current.version,
        currentBuild: current.buildNumber,
        remote: release.version,
        remoteBuild: release.buildNumber,
      );
      _talker.debug(
        'Updater: installed ${current.version}+${current.buildNumber}, '
        'latest ${release.tagName}',
      );

      if (!newer) {
        await purgeOtherApks(_updatesDir);
        return const Success(UpdateCheckUpToDate());
      }

      final path = apkPath(_updatesDir, release.version, release.buildNumber);
      final file = File(path);
      final status = cachedApkStatus(file, release.sizeBytes);

      if (status == CachedApkStatus.complete) {
        await purgeOtherApks(_updatesDir, keep: path);
        return Success(UpdateCheckReady(release: release, filePath: path));
      }

      if (status == CachedApkStatus.oversized) {
        await file.delete();
      }

      await purgeOtherApks(_updatesDir, keep: path);
      return Success(
        UpdateCheckNeedsDownload(
          release: release,
          filePath: path,
          existingBytes: existingApkBytes(file),
        ),
      );
    } catch (e, st) {
      _talker.handle(e, st, 'Updater: failed to check for updates');
      return Failure('Failed to check for updates: $e');
    }
  }

  Stream<int> downloadApk(
    AppRelease release, {
    required String toPath,
    int existingBytes = 0,
  }) {
    StreamSubscription<List<int>>? subscription;
    IOSink? sink;
    final controller = StreamController<int>();
    var received = existingBytes;

    controller.onListen = () async {
      try {
        await File(toPath).parent.create(recursive: true);
        final request = http.Request('GET', Uri.parse(release.downloadUrl));
        if (existingBytes > 0) {
          request.headers[HttpHeaders.rangeHeader] = 'bytes=$existingBytes-';
        }
        final response = await _client.send(request);
        final status = response.statusCode;
        if (status != 200 && status != 206) {
          throw Exception('HTTP error: $status');
        }

        final append = status == 206 && existingBytes > 0;
        if (!append) received = 0;

        sink = File(
          toPath,
        ).openWrite(mode: append ? FileMode.append : FileMode.write);
        subscription = response.stream.listen(
          (chunk) {
            received += chunk.length;
            sink!.add(chunk);
            controller.add(received);
          },
          onDone: () async {
            await sink!.close();
            final length = await File(toPath).length();
            if (length != release.sizeBytes) {
              controller.addError(
                Exception(
                  'Incomplete download: $length != ${release.sizeBytes}',
                ),
              );
            }
            await controller.close();
          },
          onError: (Object e, StackTrace st) async {
            await sink?.close();
            controller.addError(e, st);
            await controller.close();
          },
          cancelOnError: true,
        );
      } catch (e, st) {
        controller.addError(e, st);
        await controller.close();
      }
    };
    controller.onCancel = () async {
      await subscription?.cancel();
      await sink?.close();
    };

    return controller.stream;
  }

  Future<Result<void>> install(String filePath) async {
    try {
      final allowed = await _installer.canInstallPackages();
      if (!allowed) {
        await _installer.openInstallSettings();
        return const Failure(
          'Grant "install unknown apps" permission and try again',
        );
      }

      final result = await _installer.installApk(filePath);
      if (result.successful) {
        _talker.info('Updater: installer launched for $filePath');
        return const Success(null);
      }
      final errorMsg = result.error ?? 'Unknown install error';
      _talker.error('Updater: install error: $errorMsg');
      return Failure(errorMsg);
    } catch (e, st) {
      _talker.handle(e, st, 'Updater: bridge crashed on install');
      return Failure('System failure: $e', e);
    }
  }

  @disposeMethod
  void dispose() => _client.close();
}
