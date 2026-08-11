import 'dart:convert';
import 'dart:io';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:slipstream/core/models/stored_subscription/stored_subscription.dart';
import 'subscription_storage.dart';

class FileSubscriptionStorage implements SubscriptionStorage {
  static const _schemaVersion = 1;
  static const _tmpSuffix = '.tmp';

  final Directory _dir;
  final Talker _talker;

  FileSubscriptionStorage(Directory baseDir, Talker talker)
    : _dir = Directory('${baseDir.path}${Platform.pathSeparator}subscriptions'),
      _talker = talker;

  @override
  Future<List<StoredSubscription>> loadAll() async {
    if (!await _dir.exists()) return [];

    final result = <StoredSubscription>[];
    await for (final entry in _dir.list()) {
      if (entry is! File) continue;

      if (entry.path.endsWith(_tmpSuffix)) {
        _talker.warning('Storage: deleting an unfinished file ${entry.path}');
        await entry.delete();
        continue;
      }
      if (!entry.path.endsWith('.json')) continue;

      final subscription = await _tryRead(entry);
      if (subscription != null) result.add(subscription);
    }

    _talker.debug('Storage: loaded subscriptions: ${result.length}');
    return result;
  }

  @override
  Future<void> save(StoredSubscription subscription) async {
    await _dir.create(recursive: true);

    final envelope = {'version': _schemaVersion, 'data': subscription.toJson()};

    final target = _fileFor(subscription.subscription.id);
    final tmp = File('${target.path}$_tmpSuffix');
    await tmp.writeAsString(jsonEncode(envelope), flush: true);
    await tmp.rename(target.path);

    _talker.debug(
      'Storage: saved subscription ${subscription.subscription.id}',
    );
  }

  @override
  Future<void> delete(String subscriptionId) async {
    final file = _fileFor(subscriptionId);
    if (await file.exists()) {
      await file.delete();
      _talker.debug('Storage: deleted subscription $subscriptionId');
    }
  }

  Future<StoredSubscription?> _tryRead(File file) async {
    try {
      final envelope = jsonDecode(await file.readAsString());
      if (envelope is! Map<String, dynamic>) {
        throw const FormatException('root element is not an object');
      }

      final version = envelope['version'];
      if (version is! int || version > _schemaVersion) {
        _talker.warning(
          'Storage: skipping ${file.path} — unsupported version $version',
        );
        return null;
      }

      return StoredSubscription.fromJson(
        envelope['data'] as Map<String, dynamic>,
      );
    } catch (e, st) {
      _talker.handle(e, st, 'Storage: failed to read ${file.path}');
      return null;
    }
  }

  File _fileFor(String subscriptionId) {
    if (subscriptionId.isEmpty ||
        subscriptionId.contains('/') ||
        subscriptionId.contains('\\') ||
        subscriptionId.contains('..')) {
      throw ArgumentError.value(subscriptionId, 'subscriptionId');
    }
    return File('${_dir.path}${Platform.pathSeparator}$subscriptionId.json');
  }
}
