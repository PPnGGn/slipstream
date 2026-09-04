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
  bool apkSignatureMatchesInstalled(String filePath);
  @async
  String? exportApkToDownloads(String filePath, String fileName);
  void uninstallSelf();
  @async
  InstallResult installApk(String filePath);
}
