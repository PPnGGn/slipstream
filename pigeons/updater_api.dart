import 'package:pigeon/pigeon.dart';

class AppVersionMessage {
  String version;
  int buildNumber;
}

class InstallResult {
  bool successful;
  String? error;
}

@HostApi()
abstract class UpdateInstaller {
  AppVersionMessage getAppVersion();
  bool canInstallPackages();
  void openInstallSettings();
  @async
  InstallResult installApk(String filePath);
}
