import 'dart:typed_data';

import 'package:injectable/injectable.dart';
import 'package:slipstream/features/split_tunnel/data/installed_apps_api.g.dart';
import 'package:talker_flutter/talker_flutter.dart';

@lazySingleton
class InstalledAppsRepository {
  InstalledAppsRepository(this._api, this._talker);

  final InstalledAppsApi _api;
  final Talker _talker;

  final Map<String, Future<Uint8List?>> _icons = {};

  Future<List<InstalledAppMessage>> load() async {
    final apps = [...await _api.installedApps()];
    apps.sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    return apps;
  }

  Future<Uint8List?> icon(String packageName) =>
      _icons.putIfAbsent(packageName, () => _loadIcon(packageName));

  Future<Uint8List?> _loadIcon(String packageName) async {
    try {
      return await _api.appIcon(packageName);
    } catch (e) {
      _talker.warning('Split tunnel: no icon for $packageName: $e');
      _icons.remove(packageName);
      return null;
    }
  }
}
