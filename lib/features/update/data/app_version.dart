({List<int> core, int build}) parseAppVersion(String version) {
  final parts = version.split('+');
  final core = parts.first.split('.').map(int.parse).toList();
  final build = parts.length > 1 ? int.parse(parts[1]) : 0;
  return (core: core, build: build);
}

bool isNewerVersion({
  required String current,
  required int currentBuild,
  required String remote,
  required int remoteBuild,
}) {
  final currentCore = parseAppVersion(current).core;
  final remoteCore = parseAppVersion(remote).core;

  for (var i = 0; i < remoteCore.length; i++) {
    final c = i < currentCore.length ? currentCore[i] : 0;
    if (remoteCore[i] != c) return remoteCore[i] > c;
  }
  return remoteBuild > currentBuild;
}
