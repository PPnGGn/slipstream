import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:injectable/injectable.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:slipstream/core/models/app_release/app_release.dart';
import 'package:slipstream/core/models/result.dart';
import 'package:slipstream/features/update/data/app_version.dart';
import 'package:slipstream/features/update/data/github_release_api.dart';
import 'package:slipstream/features/update/data/updater_api.g.dart';

@lazySingleton
class UpdateRepository {
  final Talker _talker;
  final GithubReleaseApi _releaseApi;
  final UpdateInstaller _installer;
  final http.Client _client = http.Client();

  UpdateRepository(Talker talker, this._installer)
    : _talker = talker,
      _releaseApi = GithubReleaseApi();

  Future<Result<AppRelease?>> checkForUpdate() async {
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
      return Success(newer ? release : null);
    } catch (e, st) {
      _talker.handle(e, st, 'Updater: failed to check for updates');
      return Failure('Failed to check for updates: $e');
    }
  }

  Stream<int> downloadApk(AppRelease release, {required String toPath}) {
    StreamSubscription<List<int>>? subscription;
    IOSink? sink;
    final controller = StreamController<int>();
    var received = 0;

    controller.onListen = () async {
      try {
        final request = http.Request('GET', Uri.parse(release.downloadUrl));
        final response = await _client.send(request);
        if (response.statusCode != 200) {
          throw Exception('HTTP error: ${response.statusCode}');
        }

        sink = File(toPath).openWrite();
        subscription = response.stream.listen(
          (chunk) {
            received += chunk.length;
            sink!.add(chunk);
            controller.add(received);
          },
          onDone: () async {
            await sink!.close();
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
      await File(toPath).delete().catchError((_) => File(toPath));
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
