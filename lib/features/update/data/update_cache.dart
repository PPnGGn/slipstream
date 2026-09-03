import 'dart:io';

enum CachedApkStatus { missing, partial, complete, oversized }

String apkFileName(String version, int buildNumber) =>
    'slipstream-$version+$buildNumber.apk';

String apkPath(Directory updatesDir, String version, int buildNumber) =>
    '${updatesDir.path}${Platform.pathSeparator}${apkFileName(version, buildNumber)}';

CachedApkStatus cachedApkStatus(File file, int sizeBytes) {
  if (!file.existsSync()) return CachedApkStatus.missing;
  final length = file.lengthSync();
  if (length == sizeBytes) return CachedApkStatus.complete;
  if (length > sizeBytes) return CachedApkStatus.oversized;
  return CachedApkStatus.partial;
}

int existingApkBytes(File file) => file.existsSync() ? file.lengthSync() : 0;

Future<void> purgeOtherApks(Directory updatesDir, {String? keep}) async {
  if (!updatesDir.existsSync()) return;
  await for (final entry in updatesDir.list()) {
    if (entry is File && entry.path.endsWith('.apk') && entry.path != keep) {
      await entry.delete();
    }
  }
}
