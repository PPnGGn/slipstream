import 'package:pigeon/pigeon.dart';

class InstalledAppMessage {
  String packageName;
  String label;
  bool isSystem;
}

@HostApi()
abstract class InstalledAppsApi {
  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  List<InstalledAppMessage> installedApps();

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  Uint8List? appIcon(String packageName);
}
