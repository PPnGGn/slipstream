import 'dart:async';
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

  /// When set, installedApps waits for it before answering: a test closes the
  /// cubit meanwhile, like a page that is left while the list still loads.
  Completer<void>? listGate;

  int listCalls = 0;
  int iconCalls = 0;

  @override
  Future<List<InstalledAppMessage>> installedApps() async {
    listCalls++;
    await listGate?.future;
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
