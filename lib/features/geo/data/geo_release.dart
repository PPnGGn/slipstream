/// A GitHub release of the geo-rules repo and the assets attached to it.
class GeoRelease {
  const GeoRelease({required this.tag, required this.assets});

  final String tag;
  final Map<String, GeoAsset> assets;

  GeoAsset assetOrThrow(String name) {
    final a = assets[name];
    if (a == null) {
      throw Exception('Release $tag has no "$name" asset');
    }
    return a;
  }

  int get totalBytes => assets.values.fold(0, (sum, a) => sum + a.size);
}

class GeoAsset {
  const GeoAsset({required this.name, required this.url, required this.size});

  final String name;
  final String url;
  final int size;
}
