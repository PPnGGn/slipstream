import 'dart:convert';
import 'dart:io';
import 'geo_catalog.dart';
import 'geo_source.dart';

/// `geo.meta.json` — the local record of what geo data is installed, written
/// next to the .dat files after a successful download. Its presence + a
/// checksum match against the actual files is what makes geo "ready".
class GeoMeta {
  const GeoMeta({
    required this.tag,
    required this.updatedAt,
    required this.sha256,
    required this.catalog,
  });

  final String tag;
  final DateTime updatedAt;

  /// filename -> lowercase hex sha256, for the .dat files.
  final Map<String, String> sha256;
  final GeoCatalog catalog;

  static File file(String geoDir) =>
      File('$geoDir${Platform.pathSeparator}${GeoSource.metaFile}');

  static Future<GeoMeta?> read(String geoDir) async {
    final f = file(geoDir);
    if (!f.existsSync()) return null;
    try {
      final json = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      return GeoMeta(
        tag: json['tag'] as String,
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        sha256: (json['sha256'] as Map).cast<String, String>(),
        catalog: GeoCatalog.fromJson(
          (json['catalog'] as Map).cast<String, dynamic>(),
        ),
      );
    } catch (_) {
      return null; // corrupt -> treat as not installed
    }
  }

  Future<void> write(String geoDir) async {
    await file(geoDir).writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'tag': tag,
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        'sha256': sha256,
        'catalog': catalog.toJson(),
      }),
      flush: true,
    );
  }
}
