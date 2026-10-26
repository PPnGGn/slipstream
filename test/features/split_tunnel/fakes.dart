import 'dart:typed_data';

import 'package:slipstream/features/split_tunnel/data/installed_apps_api.g.dart';

InstalledAppMessage app(
  String packageName, {
  String? label,
  bool isSystem = false,
}) => InstalledAppMessage(
  packageName: packageName,
  label: label ?? packageName,
  isSystem: isSystem,
);

class FakeInstalledAppsApi extends InstalledAppsApi {
  FakeInstalledAppsApi({this.apps = const [], this.icons = const {}});

  List<InstalledAppMessage> apps;
  Map<String, Uint8List> icons;

  Object? listError;
  Object? iconError;

  int listCalls = 0;
  int iconCalls = 0;

  @override
  Future<List<InstalledAppMessage>> installedApps() async {
    listCalls++;
    final failure = listError;
    if (failure != null) throw failure;
    return apps;
  }

  @override
  Future<Uint8List?> appIcon(String packageName) async {
    iconCalls++;
    await Future<void>.delayed(Duration.zero);
    final failure = iconError;
    if (failure != null) throw failure;
    return icons[packageName];
  }
}
